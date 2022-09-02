// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interface/IORMakerDeposit.sol";
import "./library/Operation.sol";
import "./interface/IORManagerFactory.sol";
import "./interface/IORProtocal.sol";
import "./interface/IERC20.sol";
import "./interface/IORSpv.sol";
import "./interface/IORMakerV1Factory.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ORMakerDeposit is IORMakerDeposit, Initializable, OwnableUpgradeable {
    address makerFactory;
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

    function initialize(address _owner, address _makerFactory) public initializer {
        _transferOwnership(_owner);
        makerFactory = _makerFactory;
        emit MakerContract(owner(), address(this));
        address fact = getManagerAddress();
    }

    function getManagerAddress() internal view returns (address) {
        return IORMakerV1Factory(makerFactory).getManager();
    }

    function getEBCAddress(uint256 ebcid) internal view returns (address) {
        address manager = getManagerAddress();
        address ebcAddress = IORManagerFactory(manager).getEBC(ebcid);
        return ebcAddress;
    }

    function getChainInfoByChainID(uint256 chainId) internal view returns (OperationsLib.chainInfo memory) {
        address manager = getManagerAddress();
        OperationsLib.chainInfo memory chainInfo = IORManagerFactory(manager).getChainInfoByChainID(chainId);
        return chainInfo;
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
        address manager = getManagerAddress();
        return IORManagerFactory(manager).getTokenInfo(_lpinfo.sourceChain, _lpinfo.sourceTAddress);
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
        address manager = getManagerAddress();
        address spvAddress = IORManagerFactory(manager).getSPV();
        require(spvAddress != address(0), "SPV_NOT_INSTALL");
        return spvAddress;
    }

    function LPAction(
        OperationsLib.lpInfo[] calldata _lpinfos,
        bytes32[][] calldata proof,
        bytes32[][] calldata pairProof
    ) external payable {
        require(_lpinfos.length == proof.length, "Inconsistent Array Length");
        require(_lpinfos.length > 0, "Inconsistent Array Length");
        OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfos[0]);
        address pledgedToken = depositToken.mainTokenAddress;
        OperationsLib.chainDeposit storage chainPledged = chainDeposit[_lpinfos[0].sourceChain][pledgedToken];
        // free
        uint256 unUsedAmount = idleAmount(pledgedToken);
        // Need to be supplemented
        uint256 supplement = 0;
        address manager = getManagerAddress();
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            bytes32 lpid = OperationsLib.getLpID(_lpinfo);
            require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime != 0, "LP Not Paused");
            require(IORManagerFactory(manager).isSupportPair(lpid, pairProof[i]), "Pair Not Supported");
            if (
                !(_lpinfo.sourceChain == _lpinfos[0].sourceChain &&
                    _lpinfo.sourceTAddress == _lpinfos[0].sourceTAddress)
            ) {
                revert("LP of multiple pledge currencies is not supported");
            }
            // first init lpPair
            lpInfo[lpid].LPRootHash = MerkleProof.processProofCalldata(proof[i], lpid);
            require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime == 0, "LPACTION_LPID_UNSTOP");
            OperationsLib.chainInfo memory souceChainInfo = IORManagerFactory(manager).getChainInfoByChainID(
                _lpinfo.sourceChain
            );
            depositToken = getDepositTokenInfo(_lpinfo);
            if (i > 0 && depositToken.mainTokenAddress != pledgedToken) {
                revert("LP that does not support multiple pledge tokens");
            }
            uint256 needDepositAmount = souceChainInfo.batchLimit * _lpinfo.maxPrice;
            lpInfo[lpid].startTime = block.timestamp;
            _lpinfo.startTime = block.timestamp;
            if (needDepositAmount > chainPledged.depositAmount) {
                supplement = (needDepositAmount - chainPledged.depositAmount);
            }
            chainPledged.useLimit++;
            if (!lpInfo[lpid].inlps) {
                chainPledged.lpids.push(lpid);
            }
            emit LogLpInfo(lpid, lpState.ACTION, lpInfo[lpid].startTime, _lpinfo);
        }
        if (supplement - unUsedAmount > 0) {
            // need deposit
            uint256 realNeedAmount = supplement - unUsedAmount;
            if (realNeedAmount > 0) {
                if (pledgedToken != address(0)) {
                    uint256 allowance = IERC20(pledgedToken).allowance(msg.sender, address(this));
                    require(allowance >= realNeedAmount, "Check the token allowance");
                    IERC20(pledgedToken).transferFrom(msg.sender, address(this), realNeedAmount);
                    usedDeposit[pledgedToken] += realNeedAmount;
                } else {
                    require(msg.value >= realNeedAmount, "Check the eth send");
                    // user deposit
                    usedDeposit[pledgedToken] += realNeedAmount;
                }
            }
        }
    }

    // LPPause
    function LPPause(OperationsLib.lpInfo[] calldata _lpinfos, bytes32[][] calldata proof) external {
        require(_lpinfos.length == proof.length, "InconsistentArrayLength");
        address manager = getManagerAddress();
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            // calc root Hash
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            bytes32 lpid = OperationsLib.getLpID(_lpinfo);
            require(lpInfo[lpid].LPRootHash != "", "LPPAUSE_LPID_UNUSED");
            require(lpInfo[lpid].startTime != 0 && lpInfo[lpid].stopTime == 0, "LPPAUSE_LPID_UNACTION");
            lpInfo[lpid].LPRootHash = MerkleProof.processProofCalldata(proof[i], lpid);
            address ebcAddress = IORManagerFactory(manager).getEBC(_lpinfo.ebcid);
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

        lpInfo[lpid].stopTime = 0;

        depositInfo.useLimit--;
        // free up funds
        if (depositInfo.useLimit == 0) {
            usedDeposit[depositToken.mainTokenAddress] -= depositInfo.depositAmount;
            depositInfo.depositAmount = 0;
        }
        emit LogLpInfo(lpid, lpState.STOP, lpInfo[lpid].stopTime, _lpinfo);
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
        require(chanllengePleged == 0, "WITHDRAW_NOCHANLLENGE");
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
        // address manager = getManagerAddress();
        address ebcAddress = getEBCAddress(_lpinfo.ebcid);
        OperationsLib.chainInfo memory chainInfo = getChainInfoByChainID(_lpinfo.sourceChain);
        // TODO
        // require(
        //     IORProtocal(ebcAddress).checkUserChallenge(
        //         _lpinfo,
        //         stopTime,
        //         _txinfo,
        //         _lpProof,
        //         _midProof,
        //         _txproof,
        //         OperationsLib.getLpID(_lpinfo)
        //     ),
        //     "UC_ERROR"
        // );
        bytes32 chanllengeID = OperationsLib.getChanllengeID(_txinfo);
        require(chanllengeInfos[chanllengeID].chanllengeState == 0, "UCE_USED");
        uint256 pledgeAmount = IORProtocal(ebcAddress).getChanllengePledgeAmount();
        require(msg.value >= pledgeAmount, "UCE_PLEDGEAMOUNT");
        chanllengeInfos[chanllengeID].responseTxinfo = _txinfo.responseHash;
        chanllengeInfos[chanllengeID].pledgeAmount = pledgeAmount;
        chanllengeInfos[chanllengeID].ebcid = _lpinfo.ebcid;
        chanllengeInfos[chanllengeID].chanllengeState = 1;
        chanllengeInfos[chanllengeID].stopTime = block.timestamp + chainInfo.maxDisputeTime;
        chanllengePleged += pledgeAmount;
        emit LogChanllengeInfo(chanllengeID, chanllengeState.ACTION);
    }

    // LPStop
    function USER_LPStop(uint256 sourceChain, address tokenAddress) internal {
        address manager = getManagerAddress();
        OperationsLib.tokenInfo memory _dTinfo = IORManagerFactory(manager).getTokenInfo(sourceChain, tokenAddress);
        OperationsLib.chainDeposit storage _cDinfo = chainDeposit[sourceChain][_dTinfo.mainTokenAddress];

        bytes32[] memory lpids = _cDinfo.lpids;

        if (lpids.length != 0) {
            for (uint256 i = 0; i < lpids.length; i++) {
                lpInfo[lpids[i]].startTime = 0;
                lpInfo[lpids[i]].stopTime = 0;

                emit LogLpInfo(lpids[i], lpState.USERSTOP, 0);
            }
            delete _cDinfo.lpids;
            _cDinfo.useLimit = 0;
            _cDinfo.depositAmount = 0;
            //TODO: The funds of the maker that are released through the user's appeal must have a blocking period, and the maker cannot withdraw directly.
            usedDeposit[_dTinfo.mainTokenAddress] -= _cDinfo.depositAmount;
            _cDinfo.depositAmount = 0;
        }
    }

    // userWithDraw
    function userWithDraw(OperationsLib.txInfo memory _userTx, OperationsLib.lpInfo memory _lpinfo) external {
        bytes32 chanllengeID = OperationsLib.getChanllengeID(_userTx);
        address manager = getManagerAddress();
        require(_userTx.sourceAddress == msg.sender, "UW_SENDER");
        require(chanllengeInfos[chanllengeID].chanllengeState == 1, "UW_WITHDRAW");
        require(block.timestamp > chanllengeInfos[chanllengeID].stopTime, "UW_TIME");

        address ebcAddress = IORManagerFactory(manager).getEBC(chanllengeInfos[chanllengeID].ebcid);
        require(ebcAddress != address(0), "UW_EBCADDRESS_0");
        uint256 withDrawAmount = 0;
        uint256 unUsedAmount = idleAmount(_userTx.tokenAddress);
        if (_userTx.tokenAddress != address(0)) {
            withDrawAmount = IORProtocal(ebcAddress).getTokenPunish(_userTx.amount);
        } else {
            withDrawAmount =
                chanllengeInfos[chanllengeID].pledgeAmount +
                IORProtocal(ebcAddress).getETHPunish(_userTx.amount);
        }
        if (withDrawAmount > unUsedAmount) {
            USER_LPStop(_lpinfo.sourceChain, _lpinfo.sourceTAddress);
        }
        if (_userTx.tokenAddress != address(0)) {
            uint256 withDrawPledge = chanllengeInfos[chanllengeID].pledgeAmount;
            IERC20(_userTx.tokenAddress).transfer(msg.sender, withDrawAmount);
            payable(msg.sender).transfer(withDrawPledge);
        } else {
            payable(msg.sender).transfer(withDrawAmount);
        }
        chanllengePleged -= chanllengeInfos[chanllengeID].pledgeAmount;
        emit LogChanllengeInfo(chanllengeID, chanllengeState.WITHDRAWED);
    }

    // makerChanllenger
    function makerChanllenger(
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
        bytes32[] memory _makerProof
    ) external {
        address manager = getManagerAddress();
        bytes32 chanllengeID = OperationsLib.getChanllengeID(_userTx);
        require(chanllengeInfos[chanllengeID].chanllengeState == 1, "MC_ANSWER");
        address ebcAddress = IORManagerFactory(manager).getEBC(chanllengeInfos[chanllengeID].ebcid);
        require(IORProtocal(ebcAddress).checkMakerChallenge(_userTx, _makerTx, _makerProof), "MC_ERROR");
        bytes32 makerResponse = keccak256(
            abi.encodePacked(
                _makerTx.lpid,
                _makerTx.chainID,
                _makerTx.txHash,
                _makerTx.sourceAddress,
                _makerTx.destAddress,
                _makerTx.amount,
                _makerTx.tokenAddress
            )
        );
        require(chanllengeInfos[chanllengeID].responseTxinfo == makerResponse, "MCE_UNMATCH");
        chanllengeInfos[chanllengeID].chanllengeState = 2;
        chanllengePleged -= chanllengeInfos[chanllengeID].pledgeAmount;

        emit LogChanllengeInfo(chanllengeID, chanllengeState.RESPONSED);
    }
}
