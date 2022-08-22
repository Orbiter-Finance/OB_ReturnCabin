// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./interface/IORMakerDeposit.sol";
import "./library/Operation.sol";
import "./interface/IORManagerFactory.sol";
import "./interface/IORProtocal.sol";
import "./interface/IERC20.sol";

contract ORMakerDeposit is IORMakerDeposit {
    address _owner;
    address _managerAddress;
    // lpid->lpPairInfo
    mapping(bytes32 => Operations.lpPairInfo) public lpInfo;

    // supportChain->supportToken->chainDepost
    mapping(uint256 => mapping(address => Operations.chainDeposit)) public chainDeposit;

    // chanllengeInfos
    mapping(bytes32 => Operations.chanllengeInfo) chanllengeInfos;

    //usedDeposit
    mapping(address => uint256) usedDeposit;

    constructor(address managerAddress) payable {
        _owner = msg.sender;
        _managerAddress = managerAddress;
        emit MakerContract(_owner, address(this));
    }

    modifier isOwner() {
        require(msg.sender == _owner, "NOT_OWNER");
        _;
    }

    function getLpID(Operations.lpInfo memory _lpinfo) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _lpinfo.sourceChain,
                    _lpinfo.destChain,
                    _lpinfo.sourceTAddress,
                    _lpinfo.destTAddress,
                    _lpinfo.ebcid
                )
            );
    }

    function getDepositTokenInfo(Operations.lpInfo memory _lpinfo) internal returns (Operations.tokenInfo memory) {
        return
            IORManagerFactory(_managerAddress).getTokenInfo(
                _lpinfo.sourceChain,
                _lpinfo.sourceTAddress,
                _lpinfo.tokenName
            );
    }

    function getChainDepositInfo(Operations.lpInfo memory _lpinfo) internal returns (Operations.chainDeposit memory) {
        Operations.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfo);
        return chainDeposit[_lpinfo.sourceChain][depositToken.mainTokenAddress];
    }

    function LPAction(Operations.lpInfo memory _lpinfo) external payable {
        bytes32 lpid = getLpID(_lpinfo);
        // first init lpPair
        if (lpInfo[lpid].isUsed == false) {
            bytes32 rootHash = keccak256(
                abi.encodePacked(
                    _lpinfo.sourceChain,
                    _lpinfo.destChain,
                    _lpinfo.sourceTAddress,
                    _lpinfo.destTAddress,
                    _lpinfo.tokenName,
                    _lpinfo.tokenPresion,
                    _lpinfo.ebcid,
                    _lpinfo.minPrice,
                    _lpinfo.maxPrice,
                    _lpinfo.gasFee,
                    _lpinfo.tradingFee
                )
            );
            lpInfo[lpid].LPRootHash = rootHash;
            lpInfo[lpid].isUsed = true;
        }

        require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime == 0, "LPACTION_LPID_UNSTOP");

        Operations.chainInfo memory souceChainInfo = IORManagerFactory(_managerAddress).getChainInfoByChainID(
            _lpinfo.sourceChain
        );
        uint256 needDepositAmount = souceChainInfo.batchLimit * _lpinfo.maxPrice;

        Operations.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfo);

        Operations.chainDeposit memory depositInfo = getChainDepositInfo(_lpinfo);

        lpInfo[lpid].startTime = block.timestamp;

        if (needDepositAmount > depositInfo.depositAmount) {
            uint256 balance = 0;
            if (depositToken.mainTokenAddress != address(0)) {
                IERC20 liquidityToken = IERC20(depositToken.mainTokenAddress);
                balance = liquidityToken.balanceOf(address(this));
            } else {
                balance = address(this).balance;
            }
            uint256 unUsedAmount = balance - usedDeposit[depositToken.mainTokenAddress];

            require(unUsedAmount > needDepositAmount - depositInfo.depositAmount, "LPACTION_INSUFFICIENT_AMOUNT");
            depositInfo.depositAmount = needDepositAmount;
        }
        depositInfo.useLimit++;
        emit LogLpState(lpid, lpInfo[lpid].startTime, lpState.ACTION);
        emit LogLpInfo(lpid, _lpinfo.sourceChain, _lpinfo.destChain, _lpinfo);
    }

    // LPPause
    function LPPause(Operations.lpInfo memory _lpinfo) external {
        bytes32 lpid = getLpID(_lpinfo);

        require(lpInfo[lpid].isUsed == true, "LPPAUSE_LPID_UNUSED");
        require(lpInfo[lpid].startTime != 0 && lpInfo[lpid].stopTime == 0, "LPPAUSE_LPID_UNACTION");

        address ebcAddress = IORManagerFactory(_managerAddress).getEBC(_lpinfo.ebcid);
        require(ebcAddress != address(0), "LPPAUSE_EBCADDRESS_0");

        uint256 stopDelayTime = IORProtocal(ebcAddress).getStopDealyTime(_lpinfo.sourceChain);
        lpInfo[lpid].stopTime = block.timestamp + stopDelayTime;
        lpInfo[lpid].startTime = 0;

        emit LogLpState(lpid, lpInfo[lpid].stopTime, lpState.PAUSE);
    }

    // LPStop
    function LPStop(Operations.lpInfo memory _lpinfo) external {
        bytes32 lpid = getLpID(_lpinfo);

        require(lpInfo[lpid].isUsed == true, "LPSTOP_LPID_UNUSED");
        require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime != 0, "LPSTOP_LPID_UNPAUSE");
        require(block.timestamp > lpInfo[lpid].stopTime, "LPSTOP_LPID_TIMEUNABLE");

        Operations.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfo);

        Operations.chainDeposit memory depositInfo = getChainDepositInfo(_lpinfo);

        depositInfo.useLimit--;

        // free up funds
        if (depositInfo.useLimit == 0) {
            usedDeposit[depositToken.mainTokenAddress] -= depositInfo.depositAmount;
            depositInfo.depositAmount = 0;
        }

        emit LogLpState(lpid, 0, lpState.STOP);
    }

    // LPUpdate
    function LPUpdate(
        Operations.lpInfo memory _lpinfo,
        bytes32 proof,
        bool[] memory flag
    ) external {
        bytes32 lpid = getLpID(_lpinfo);

        require(lpInfo[lpid].isUsed == true, "LPUPDATE_LPID_UNUSED");
        require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime == 0, "LPUPDATE_LPID_UNSTOP");

        // TODO
        // proof and generate a new Roothash
        console.logBytes32(proof);
        console.log(flag[0]);
        lpInfo[lpid].LPRootHash = "xxxxxxxxx";

        emit LogLpState(lpid, block.timestamp, lpState.UPDATE);
        emit LogLpInfo(lpid, _lpinfo.sourceChain, _lpinfo.destChain, _lpinfo);
    }

    // withDrawAssert()
    function withDrawAssert(uint256 amount, address tokenAddress) external isOwner {
        require(amount != 0, "WITHDRAW_ILLEGALAMOUNT");
        uint256 balance = 0;
        if (tokenAddress != address(0)) {
            IERC20 Token = IERC20(tokenAddress);
            balance = Token.balanceOf(address(this));
        } else {
            balance = address(this).balance;
        }

        uint256 unUsedAmount = balance - usedDeposit[tokenAddress];
        require(amount < unUsedAmount, "WITHDRAW_INSUFFICIENT_AMOUNT");

        if (tokenAddress != address(0)) {
            IERC20(tokenAddress).transfer(msg.sender, amount);
        } else {
            payable(_owner).transfer(amount);
        }
    }

    // userChanllenge
    function userChanllenge(
        Operations.lpInfo memory _lpinfo,
        Operations.txInfo memory _txinfo,
        bytes memory _proof
    ) external returns (bool) {
        //TODO
        //1. txinfo is already spv
        //2. txinfo unChanllenge
        bytes32 chanllengeID = keccak256(
            abi.encodePacked(
                _txinfo.sourceAddress,
                _txinfo.destAddress,
                _txinfo.tokenName,
                _txinfo.tokenAmount,
                _txinfo.nonce,
                _txinfo.gas
            )
        );
        require(chanllengeInfos[chanllengeID].chanllengeState == 0, "USERCHANLLENGE_USED");
        //3. get response changellengeinfo
        bytes32 responseInfoHash = "000000000";
        chanllengeInfos[chanllengeID].responseTxinfo = responseInfoHash;
        chanllengeInfos[chanllengeID].chanllengeState = 1;
        chanllengeInfos[chanllengeID].startTime = block.timestamp;
        return true;
    }

    // userWithDraw
    function userWithDraw(Operations.txInfo memory userInfo) external returns (bool) {
        console.log(userInfo.sourceAddress);
        return true;
    }

    // makerChanllenger
    function makerChanllenger(
        Operations.txInfo memory _userTx,
        Operations.txInfo memory _makerTx,
        bytes memory proof
    ) external returns (bool) {
        bytes32 chanllengeID = keccak256(
            abi.encodePacked(
                _userTx.sourceAddress,
                _userTx.destAddress,
                _userTx.tokenName,
                _userTx.tokenAmount,
                _userTx.nonce,
                _userTx.gas
            )
        );
        require(chanllengeInfos[chanllengeID].chanllengeState == 1, "MAKERCHANLLENGE_WATTINGFORANSWER");
        bytes32 makerResponse = "000000000";
        require(chanllengeInfos[chanllengeID].responseTxinfo == makerResponse, "MAKERCHANLLENGE_UNMATCH");
        chanllengeInfos[chanllengeID].chanllengeState = 2;
        console.logBytes(proof);
        return true;
    }
}
