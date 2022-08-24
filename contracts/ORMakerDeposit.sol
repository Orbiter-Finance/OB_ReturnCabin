// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";
import "./interface/IORMakerDeposit.sol";
import "./library/Operation.sol";
import "./interface/IORManagerFactory.sol";
import "./interface/IORPairManager.sol";
import "./interface/IORProtocal.sol";
import "./interface/IERC20.sol";
import "./interface/IORSpv.sol";

contract ORMakerDeposit is IORMakerDeposit, Ownable {
    address _owner;
    address _managerAddress;
    IORSpv public _spv;
    // lpid->lpPairInfo
    mapping(bytes32 => OperationsLib.lpPairInfo) public lpInfo;

    // supportChain->supportToken->chainDepost
    mapping(uint256 => mapping(address => OperationsLib.chainDeposit)) public chainDeposit;

    // chanllengeInfos
    mapping(bytes32 => OperationsLib.chanllengeInfo) chanllengeInfos;

    //usedDeposit
    mapping(address => uint256) usedDeposit;

    // chanllenge pleged eth amount
    uint256 chanllengePleged;

    constructor(address managerAddress) payable {
        _managerAddress = managerAddress;
        emit MakerContract(_owner, address(this));
    }

    function idleAmount(address tokenAddress) public view returns (uint256) {
        uint256 balance = 0;
        if (tokenAddress != address(0)) {
            IERC20 liquidityToken = IERC20(tokenAddress);
            balance = liquidityToken.balanceOf(address(this));
        } else {
            balance = address(this).balance;
        }
        uint256 idleamount = balance - usedDeposit[tokenAddress] - chanllengePleged;
        return idleamount;
    }

    function getDepositTokenInfo(OperationsLib.lpInfo memory _lpinfo)
        internal
        view
        returns (OperationsLib.tokenInfo memory)
    {
        return IORManagerFactory(_managerAddress).getTokenInfo(_lpinfo.sourceChain, _lpinfo.sourceTAddress);
    }

    function getChainDepositInfo(OperationsLib.lpInfo memory _lpinfo)
        internal
        view
        returns (OperationsLib.chainDeposit memory)
    {
        OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfo);
        return chainDeposit[_lpinfo.sourceChain][depositToken.mainTokenAddress];
    }

    function LPAction(
        OperationsLib.lpInfo memory _lpinfo,
        bytes32[] memory proof,
        bytes32 rootHash
    ) external payable {
        bytes32 lpid = OperationsLib.getLpID(_lpinfo);
        // first init lpPair
        require(IORPairManager(_managerAddress).isSupportPair(lpid, proof), "PairNotSupported");
        if (lpInfo[lpid].LPRootHash == "") {
            lpInfo[lpid].LPRootHash = rootHash;
        }
        require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime == 0, "LPACTION_LPID_UNSTOP");

        OperationsLib.chainInfo memory souceChainInfo = IORManagerFactory(_managerAddress).getChainInfoByChainID(
            _lpinfo.sourceChain
        );
        uint256 needDepositAmount = souceChainInfo.batchLimit * _lpinfo.maxPrice;

        OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfo);

        OperationsLib.chainDeposit memory depositInfo = getChainDepositInfo(_lpinfo);

        lpInfo[lpid].startTime = block.timestamp;
        _lpinfo.startTime = block.timestamp;

        if (needDepositAmount > depositInfo.depositAmount) {
            uint256 unUsedAmount = idleAmount(depositToken.mainTokenAddress);
            if (unUsedAmount < needDepositAmount - depositInfo.depositAmount) {
                require(
                    unUsedAmount + msg.value > needDepositAmount - depositInfo.depositAmount,
                    "LPACTION_INSUFFICIENT_AMOUNT"
                );
            }
            depositInfo.depositAmount = needDepositAmount;
        }
        depositInfo.useLimit++;
        emit LogLpInfo(lpid, lpState.ACTION, lpInfo[lpid].startTime, _lpinfo);
    }

    // LPPause
    function LPPause(OperationsLib.lpInfo memory _lpinfo, bytes32 rootHash) external {
        bytes32 lpid = OperationsLib.getLpID(_lpinfo);

        require(lpInfo[lpid].LPRootHash != "", "LPPAUSE_LPID_UNUSED");
        require(lpInfo[lpid].startTime != 0 && lpInfo[lpid].stopTime == 0, "LPPAUSE_LPID_UNACTION");

        address ebcAddress = IORManagerFactory(_managerAddress).getEBC(_lpinfo.ebcid);
        require(ebcAddress != address(0), "LPPAUSE_EBCADDRESS_0");

        uint256 stopDelayTime = IORProtocal(ebcAddress).getStopDealyTime(_lpinfo.sourceChain);
        lpInfo[lpid].stopTime = block.timestamp + stopDelayTime;
        lpInfo[lpid].startTime = 0;
        lpInfo[lpid].LPRootHash = rootHash;

        emit LogLpInfo(lpid, lpState.PAUSE, lpInfo[lpid].stopTime, _lpinfo);
    }

    // LPStop
    function LPStop(OperationsLib.lpInfo memory _lpinfo) external {
        bytes32 lpid = OperationsLib.getLpID(_lpinfo);

        require(lpInfo[lpid].LPRootHash != "", "LPSTOP_LPID_UNUSED");
        require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime != 0, "LPSTOP_LPID_UNPAUSE");
        require(block.timestamp > lpInfo[lpid].stopTime, "LPSTOP_LPID_TIMEUNABLE");

        OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfo);

        OperationsLib.chainDeposit memory depositInfo = getChainDepositInfo(_lpinfo);

        depositInfo.useLimit--;
        // free up funds
        if (depositInfo.useLimit == 0) {
            usedDeposit[depositToken.mainTokenAddress] -= depositInfo.depositAmount;
            depositInfo.depositAmount = 0;
        }
        emit LogLpInfo(lpid, lpState.STOP, 0, _lpinfo);
    }

    // LPUpdate
    function LPUpdate(
        bytes32 leaf,
        bytes32[] calldata proof,
        bool[] calldata proofFlag,
        OperationsLib.lpInfo calldata _lpinfo
    ) external {
        bytes32 lpid = OperationsLib.getLpID(_lpinfo);

        require(lpInfo[lpid].LPRootHash != "", "LPUPDATE_LPID_UNUSED");
        require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime == 0, "LPUPDATE_LPID_UNSTOP");

        // proof and generate a new Roothash
        bool isVerify = MerkleProof.verifyCalldata(proof, lpInfo[lpid].LPRootHash, leaf);
        require(isVerify, "VerifyFailed");

        // new hash
        bytes32 newLpHash = OperationsLib.getLpFullHash(_lpinfo);
        bytes32 newRootHash = MerkleProof.processProofCalldata(proof, newLpHash);
        lpInfo[lpid].LPRootHash = newRootHash;

        emit LogLpInfo(lpid, lpState.UPDATE, block.timestamp, _lpinfo);
    }

    // withDrawAssert()
    function withDrawAssert(uint256 amount, address tokenAddress) external onlyOwner {
        require(amount != 0, "WITHDRAW_ILLEGALAMOUNT");
        uint256 unUsedAmount = idleAmount(tokenAddress);
        require(amount < unUsedAmount, "WITHDRAW_INSUFFICIENT_AMOUNT");
        if (tokenAddress != address(0)) {
            IERC20(tokenAddress).transfer(msg.sender, amount);
        } else {
            payable(msg.sender).transfer(amount);
        }
    }

    // userChanllenge

    // _txinfo + _txProof
    // _lpinfo + _lpProof
    // _lpinfo + stopTime -> midHash + midProof
    function userChanllenge(
        OperationsLib.lpInfo memory _lpinfo,
        uint256 stopTime,
        OperationsLib.txInfo memory _txinfo,
        bytes memory _lpProof,
        bytes memory midProof,
        bytes memory _proof
    ) external returns (bool) {
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
    function userWithDraw(OperationsLib.txInfo memory userInfo) external returns (bool) {
        console.log(userInfo.sourceAddress);
        return true;
    }

    // makerChanllenger
    function makerChanllenger(
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
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
