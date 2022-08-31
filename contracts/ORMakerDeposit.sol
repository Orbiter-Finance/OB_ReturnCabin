// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";
import "./interface/IORMakerDeposit.sol";
import "./library/Operation.sol";
import "./interface/IORManagerFactory.sol";
import "./interface/IORProtocal.sol";
import "./interface/IERC20.sol";
import "./interface/IORSpv.sol";

contract ORMakerDeposit is IORMakerDeposit, Ownable {
    address _owner;
    address _managerAddress;

    // lpid->lpPairInfo
    mapping(bytes32 => OperationsLib.lpPairInfo) public lpInfo;

    // supportChain->supportToken->chainDepost
    mapping(uint256 => mapping(address => OperationsLib.chainDeposit)) public chainDeposit;

    // chanllengeInfos
    mapping(bytes32 => OperationsLib.chanllengeInfo) chanllengeInfos;

    //usedDeposit
    mapping(address => uint256) public usedDeposit;

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
        returns (OperationsLib.chainDeposit storage)
    {
        OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfo);
        return chainDeposit[_lpinfo.sourceChain][depositToken.mainTokenAddress];
    }

    function getSpvAddress() internal view returns (address) {
        address spvAddress = IORManagerFactory(_managerAddress).getSPV();
        require(spvAddress != address(0), "SPV_NOT_INSTALL");
        return spvAddress;
    }

    function LPAction(
        uint256 amount,
        OperationsLib.lpInfo[] calldata _lpinfos,
        bytes32[][] calldata proof,
        bytes32[][] calldata pairProof
    ) external payable {
        uint256 totalNeedDepositAmount = 0;
        uint256 accountDepositAmount = 0;
        address mainTokenAddress = address(0);
        require(_lpinfos.length == proof.length, "Inconsistent Array Length");
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            bytes32 lpid = OperationsLib.getLpID(_lpinfo);
            require(IORManagerFactory(_managerAddress).isSupportPair(lpid, pairProof[i]), "Pair Not Supported");

            if (
                !(_lpinfo.sourceChain == _lpinfos[0].sourceChain &&
                    _lpinfo.sourceTAddress == _lpinfos[0].sourceTAddress)
            ) {
                revert("LP of multiple pledge currencies is not supported");
            }
            // first init lpPair
            lpInfo[lpid].LPRootHash = MerkleProof.processProofCalldata(proof[i], lpid);
            require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime == 0, "LPACTION_LPID_UNSTOP");

            OperationsLib.chainInfo memory souceChainInfo = IORManagerFactory(_managerAddress).getChainInfoByChainID(
                _lpinfo.sourceChain
            );
            uint256 needDepositAmount = souceChainInfo.batchLimit * _lpinfo.maxPrice;
            OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfo);
            OperationsLib.chainDeposit memory depositInfo = getChainDepositInfo(_lpinfo);
            lpInfo[lpid].startTime = block.timestamp;
            _lpinfo.startTime = block.timestamp;
            totalNeedDepositAmount += needDepositAmount;
            accountDepositAmount += depositInfo.depositAmount;
            if (i > 0 && depositToken.mainTokenAddress != mainTokenAddress) {
                revert("LP that does not support multiple pledge tokens");
            }
            mainTokenAddress = depositToken.mainTokenAddress;
            depositInfo.depositAmount = needDepositAmount;
            depositInfo.useLimit++;
            emit LogLpInfo(lpid, lpState.ACTION, lpInfo[lpid].startTime, _lpinfo);
        }

        if (accountDepositAmount < totalNeedDepositAmount) {
            // need inject
            uint256 unUsedAmount = idleAmount(mainTokenAddress); // free
            require(
                unUsedAmount + amount > totalNeedDepositAmount - accountDepositAmount,
                "LPACTION_INSUFFICIENT_AMOUNT"
            );
            if (unUsedAmount < totalNeedDepositAmount - accountDepositAmount) {
                if (mainTokenAddress != address(0)) {
                    uint256 allowance = IERC20(mainTokenAddress).allowance(msg.sender, address(this));
                    require(allowance >= amount, "Check the token allowance");
                    IERC20(mainTokenAddress).transferFrom(msg.sender, address(this), amount);
                } else {
                    require(msg.value >= amount, "Check the eth send");
                }
            }
        }
    }

    // LPPause
    function LPPause(OperationsLib.lpInfo[] calldata _lpinfos, bytes32[][] calldata proof) external {
        require(_lpinfos.length == proof.length, "InconsistentArrayLength");
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            // calc root Hash
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            bytes32 lpid = OperationsLib.getLpID(_lpinfo);
            require(lpInfo[lpid].LPRootHash != "", "LPPAUSE_LPID_UNUSED");
            require(lpInfo[lpid].startTime != 0 && lpInfo[lpid].stopTime == 0, "LPPAUSE_LPID_UNACTION");
            lpInfo[lpid].LPRootHash = MerkleProof.processProofCalldata(proof[i], lpid);
            address ebcAddress = IORManagerFactory(_managerAddress).getEBC(_lpinfo.ebcid);
            require(ebcAddress != address(0), "LPPAUSE_EBCADDRESS_0");
            uint256 stopDelayTime = IORProtocal(ebcAddress).getStopDealyTime(_lpinfo.sourceChain);
            lpInfo[lpid].stopTime = block.timestamp + stopDelayTime;
            lpInfo[lpid].startTime = 0;
            emit LogLpInfo(lpid, lpState.PAUSE, lpInfo[lpid].stopTime, _lpinfo);
        }
    }

    // LPStop
    function LPStop(OperationsLib.lpInfo memory _lpinfo) external {
        bytes32 lpid = OperationsLib.getLpID(_lpinfo);

        require(lpInfo[lpid].LPRootHash != "", "LPSTOP_LPID_UNUSED");
        require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime != 0, "LPSTOP_LPID_UNPAUSE");
        require(block.timestamp > lpInfo[lpid].stopTime, "LPSTOP_LPID_TIMEUNABLE");

        OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfo);

        OperationsLib.chainDeposit storage depositInfo = getChainDepositInfo(_lpinfo);

        depositInfo.useLimit--;
        // free up funds
        if (depositInfo.useLimit == 0) {
            usedDeposit[depositToken.mainTokenAddress] -= depositInfo.depositAmount;
            depositInfo.depositAmount = 0;
        }
        emit LogLpInfo(lpid, lpState.STOP, 0, _lpinfo);
    }

    // LPUpdate
    function LPUpdate(OperationsLib.lpInfo calldata _lpinfo) external {
        bytes32 lpid = OperationsLib.getLpID(_lpinfo);

        require(lpInfo[lpid].LPRootHash != "", "LPUPDATE_LPID_UNUSED");
        require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime == 0, "LPUPDATE_LPID_UNSTOP");

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
        bytes32[] memory _lpProof,
        bytes32[] memory _midProof,
        bytes32[] memory _txproof
    ) external payable {
        require(userChanllengeAuthentication(_lpinfo, stopTime, _txinfo, _lpProof, _midProof, _txproof), "111");
        //3. txinfo unChanllenge
        bytes32 chanllengeID = OperationsLib.getChanllengeID(_txinfo);
        require(chanllengeInfos[chanllengeID].chanllengeState == 0, "UCE_USED");
        //3. get response changellengeinfo Todo
        address ebcAddress = IORManagerFactory(_managerAddress).getEBC(_lpinfo.ebcid);
        uint256 pledgeAmount = IORProtocal(ebcAddress).getChanllengePledgeAmount();
        require(msg.value >= pledgeAmount, "UCE_PLEDGEAMOUNT");

        bytes32 responseInfoHash = IORProtocal(ebcAddress).getResponseTxHash();
        chanllengeInfos[chanllengeID].responseTxinfo = responseInfoHash;
        chanllengeInfos[chanllengeID].pledgeAmount = pledgeAmount;
        chanllengeInfos[chanllengeID].chanllengeState = 1;
        chanllengeInfos[chanllengeID].startTime = block.timestamp;
        emit LogChanllengeInfo(chanllengeID, chanllengeState.ACTION);
    }

    function userChanllengeAuthentication(
        OperationsLib.lpInfo memory _lpinfo,
        uint256 stopTime,
        OperationsLib.txInfo memory _txinfo,
        bytes32[] memory _lpProof,
        bytes32[] memory _midProof,
        bytes32[] memory _txproof
    ) internal view returns (bool) {
        address spvAddress = getSpvAddress();
        bytes32 lpid = OperationsLib.getLpID(_lpinfo);
        //1. txinfo is already spv
        bool txVerify = IORSpv(spvAddress).verifyUserTxProof(_txinfo, _txproof);
        require(txVerify, "UCE_1");
        require(_lpinfo.sourceChain == _txinfo.chainID, "UCE_2");
        require(_lpinfo.sourceTAddress == _txinfo.tokenAddress, "UCE_3");
        require(_txinfo.destAddress == _owner, "UCE_4");
        require(_txinfo.sourceAddress == msg.sender, "UCE_5");
        require(_txinfo.timestamp > _lpinfo.startTime && _txinfo.timestamp < stopTime, "UCE_6");
        require(lpid == _txinfo.lpid, "UCE_7");
        //2. lpinfo is already proof
        bytes32 lp_leaf = OperationsLib.getLpFullHash(_lpinfo);
        bool lpVerify = SpvLib.verify(lpInfo[lpid].LPRootHash, lp_leaf, _lpProof);
        require(lpVerify, "UCE_8");
        //3. stoptime & mid is already proof
        bytes32 mid_leaf = keccak256(abi.encodePacked(lp_leaf, keccak256(abi.encodePacked(stopTime))));
        bool midVerify = SpvLib.verify(lpInfo[lpid].LPRootHash, mid_leaf, _midProof);
        require(midVerify, "UCE_9");
        return true;
    }

    // userWithDraw
    function userWithDraw(OperationsLib.txInfo memory _userTx) external {
        bytes32 chanllengeID = OperationsLib.getChanllengeID(_userTx);
        require(chanllengeInfos[chanllengeID].chanllengeState == 2, "MC_WITHDRAW");
        console.log(_userTx.sourceAddress);
        emit LogChanllengeInfo(chanllengeID, chanllengeState.WITHDRAWED);
    }

    // makerChanllenger
    function makerChanllenger(
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
        bytes32[] memory _makerProof
    ) external {
        bytes32 chanllengeID = OperationsLib.getChanllengeID(_userTx);
        require(chanllengeInfos[chanllengeID].chanllengeState == 1, "MC_ANSWER");
        address spvAddress = getSpvAddress();
        //1. _makerTx is already spv
        bool txVerify = IORSpv(spvAddress).verifyUserTxProof(_makerTx, _makerProof);
        require(txVerify, "MCE_UNVERIFY");
        bytes32 makerResponse = keccak256(
            abi.encodePacked(
                _makerTx.lpid,
                _makerTx.chainID,
                _makerTx.txHash,
                _makerTx.sourceAddress,
                _makerTx.destAddress,
                _makerTx.nonce,
                _makerTx.amount,
                _makerTx.tokenAddress
                // _txInfo.timestamp
            )
        );
        require(chanllengeInfos[chanllengeID].responseTxinfo == makerResponse, "MCE_UNMATCH");
        OperationsLib.chainInfo memory souceChainInfo = IORManagerFactory(_managerAddress).getChainInfoByChainID(
            _userTx.chainID
        );
        require(
            _makerTx.timestamp - _userTx.timestamp > 0 &&
                _makerTx.timestamp - _userTx.timestamp < souceChainInfo.maxDisputeTime,
            "MCE_TIMEINVALIDATE"
        );
        chanllengeInfos[chanllengeID].chanllengeState = 2;
        emit LogChanllengeInfo(chanllengeID, chanllengeState.RESPONSED);
    }
}
