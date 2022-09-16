// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interface/IORMakerDeposit.sol";
import "./library/Operation.sol";
import "./interface/IORManager.sol";
import "./interface/IORProtocal.sol";
import "./interface/IERC20.sol";
import "./interface/IORSpv.sol";
import "./interface/IORMakerV1Factory.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

contract ORMakerDeposit is IORMakerDeposit, Initializable, OwnableUpgradeable {
    address public makerFactory;
    // lpid->lpPairInfo
    mapping(bytes32 => OperationsLib.lpPairInfo) public lpInfo;

    // supportChain->supportToken->chainDepost
    mapping(uint256 => mapping(address => OperationsLib.chainDeposit)) public chainDeposit;

    // chanllengeInfos
    mapping(bytes32 => OperationsLib.chanllengeInfo) chanllengeInfos;

    // usedDeposit
    mapping(address => uint256) public usedDeposit;

    // After the User forcibly stops LP, Maker delays the withdrawal time.
    mapping(address => uint256) public USER_LPStopDelayTime;

    // chanllenge pleged eth amount
    uint256 chanllengePleged;

    function initialize(address _owner, address _makerFactory) public initializer {
        makerFactory = _makerFactory;
        _transferOwnership(_owner);
    }

    function getManagerAddress() internal view returns (address) {
        return IORMakerV1Factory(makerFactory).getManager();
    }

    function getEBCAddress(uint256 ebcid) internal view returns (address) {
        address manager = getManagerAddress();
        address ebcAddress = IORManager(manager).getEBC(ebcid);
        return ebcAddress;
    }

    function getChainInfoByChainID(uint256 chainId) internal view returns (OperationsLib.chainInfo memory) {
        address manager = getManagerAddress();
        OperationsLib.chainInfo memory chainInfo = IORManager(manager).getChainInfoByChainID(chainId);
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
        return IORManager(manager).getTokenInfo(_lpinfo.sourceChain, _lpinfo.sourceTAddress);
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
        address spvAddress = IORManager(manager).getSPV();
        require(spvAddress != address(0), "SPV_NOT_INSTALL");
        return spvAddress;
    }

    function LPAction(OperationsLib.lpInfo[] calldata _lpinfos, bytes32[][] calldata pairProof)
        external
        payable
        onlyOwner
    {
        require(_lpinfos.length > 0, "Inconsistent Array Length");
        require(_lpinfos.length == pairProof.length, "Inconsistent Array Length");
        OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfos[0]);
        address pledgedToken = depositToken.mainTokenAddress;
        // free
        uint256 unUsedAmount = idleAmount(pledgedToken);
        // Need to be supplemented
        uint256 supplement = 0;
        address manager = getManagerAddress();
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            bytes32 lpid = OperationsLib.getLpID(_lpinfo);
            require(IORManager(manager).isSupportPair(lpid, pairProof[i]), "Pair Not Supported");
            OperationsLib.chainDeposit storage chainPledged = chainDeposit[_lpinfo.sourceChain][pledgedToken];
            // first init lpPair
            require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime == 0, "LPACTION_LPID_UNSTOP");
            OperationsLib.chainInfo memory souceChainInfo = IORManager(manager).getChainInfoByChainID(
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
                chainPledged.depositAmount = needDepositAmount;
            }
            chainPledged.useLimit++;
            chainPledged.lpids.push(lpid);
            lpInfo[lpid].LPRootHash = true;
            // lpInfo[lpid].LPRootHash = MerkleProof.processProofCalldata(proof[i], OperationsLib.getLpFullHash(_lpinfo));
            emit LogLpInfo(lpid, lpState.ACTION, lpInfo[lpid].startTime, _lpinfo);
        }

        // need deposit
        if (pledgedToken != address(0)) {
            int256 AssessmentAmount = int256(supplement) - int256(unUsedAmount);
            if (AssessmentAmount > 0) {
                uint256 realNeedAmount = uint256(AssessmentAmount);
                uint256 allowance = IERC20(pledgedToken).allowance(msg.sender, address(this));
                require(allowance >= realNeedAmount, "Check the token allowance");
                IERC20(pledgedToken).transferFrom(msg.sender, address(this), realNeedAmount);
                usedDeposit[pledgedToken] += realNeedAmount;
            }
        } else {
            int256 AssessmentAmount = int256(supplement) - int256(unUsedAmount - msg.value);
            if (AssessmentAmount > 0) {
                uint256 realNeedAmount = uint256(AssessmentAmount);
                require(msg.value >= realNeedAmount, "Check the eth send");
                // user deposit
                usedDeposit[pledgedToken] += realNeedAmount;
            }
        }
    }

    // LPPause
    function LPPause(OperationsLib.lpInfo[] calldata _lpinfos) external onlyOwner {
        // require(_lpinfos.length == proof.length, "InconsistentArrayLength");
        address manager = getManagerAddress();
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            // calc root Hash
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            bytes32 lpid = OperationsLib.getLpID(_lpinfo);
            // require(lpInfo[lpid].LPRootHash != "", "LPPAUSE_LPID_UNUSED");
            require(lpInfo[lpid].LPRootHash == true, "LPPAUSE_LPID_UNUSED");
            require(lpInfo[lpid].startTime != 0 && lpInfo[lpid].stopTime == 0, "LPPAUSE_LPID_UNACTION");
            address ebcAddress = IORManager(manager).getEBC(_lpinfo.ebcid);
            require(ebcAddress != address(0), "LPPAUSE_EBCADDRESS_0");
            uint256 stopDelayTime = IORProtocal(ebcAddress).getStopDealyTime(_lpinfo.sourceChain);
            lpInfo[lpid].stopTime = block.timestamp + stopDelayTime;
            lpInfo[lpid].startTime = 0;
            // lpInfo[lpid].LPRootHash = MerkleProof.processProofCalldata(proof[i], OperationsLib.getLpFullHash(_lpinfo));
            emit LogLpInfo(lpid, lpState.PAUSE, lpInfo[lpid].stopTime, _lpinfo);
        }
    }

    // LPStop
    function LPStop(OperationsLib.lpInfo memory _lpinfo) external onlyOwner {
        bytes32 lpid = OperationsLib.getLpID(_lpinfo);

        // require(lpInfo[lpid].LPRootHash != "", "LPSTOP_LPID_UNUSED");
        require(lpInfo[lpid].LPRootHash == true, "LPPAUSE_LPID_UNUSED");
        require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime != 0, "LPSTOP_LPID_UNPAUSE");
        require(block.timestamp > lpInfo[lpid].stopTime, "LPSTOP_LPID_TIMEUNABLE");

        OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfo);

        OperationsLib.chainDeposit storage depositInfo = getChainDepositInfo(_lpinfo);

        lpInfo[lpid].stopTime = 0;

        depositInfo.useLimit--;

        // delete lpid
        for (uint256 i = 0; i < depositInfo.lpids.length; i++) {
            if (lpid == depositInfo.lpids[i]) {
                depositInfo.lpids[i] = depositInfo.lpids[depositInfo.lpids.length - 1];
                depositInfo.lpids.pop();
            }
        }

        // free up funds
        if (depositInfo.useLimit == 0) {
            usedDeposit[depositToken.mainTokenAddress] -= depositInfo.depositAmount;
            depositInfo.depositAmount = 0;
        }
        emit LogLpInfo(lpid, lpState.STOP, lpInfo[lpid].stopTime, _lpinfo);
    }

    // LPUpdate
    function LPUpdate(OperationsLib.lpInfo calldata _lpinfo) external onlyOwner {
        bytes32 lpid = OperationsLib.getLpID(_lpinfo);

        // require(lpInfo[lpid].LPRootHash != "", "LPUPDATE_LPID_UNUSED");
        require(lpInfo[lpid].LPRootHash == true, "LPPAUSE_LPID_UNUSED");
        require(lpInfo[lpid].startTime == 0 && lpInfo[lpid].stopTime == 0, "LPUPDATE_LPID_UNSTOP");

        emit LogLpInfo(lpid, lpState.UPDATE, block.timestamp, _lpinfo);
    }

    // withDrawAssert()
    function withDrawAssert(uint256 amount, address tokenAddress) external onlyOwner {
        // This condition is not passed only when the user withdrawals trigger a forced stop event.
        require(block.timestamp >= USER_LPStopDelayTime[tokenAddress], "WITHDRAW_NOTIME");
        require(amount != 0, "WITHDRAW_ILLEGALAMOUNT");
        require(chanllengePleged == 0, "WITHDRAW_NOCHANLLENGE");
        uint256 unUsedAmount = idleAmount(tokenAddress);
        require(amount <= unUsedAmount, "WITHDRAW_INSUFFICIENT_AMOUNT");
        if (tokenAddress != address(0)) {
            IERC20(tokenAddress).transfer(msg.sender, amount);
        } else {
            payable(msg.sender).transfer(amount);
        }
        // Cancellation of Maker withdrawal time limit
        if (USER_LPStopDelayTime[tokenAddress] != 0) {
            USER_LPStopDelayTime[tokenAddress] = 0;
        }
    }

    // userChanllenge
    // User Initiates Arbitration Request
    function userChanllenge(OperationsLib.txInfo memory _txinfo, bytes32[] memory _txproof) external payable {
        address ebcAddress = getEBCAddress(_txinfo.ebcid);
        // txinfo and txproof are provided to EBC and verified to pass
        require(IORProtocal(ebcAddress).checkUserChallenge(_txinfo, _txproof, msg.sender), "UC_ERROR");
        // Get the corresponding chanllengeID through txinfo.
        bytes32 chanllengeID = OperationsLib.getChanllengeID(_txinfo);
        // The corresponding chanllengeInfo is required to be in an unused state.
        require(chanllengeInfos[chanllengeID].chanllengeState == 0, "UCE_USED");
        uint256 pledgeAmount = IORProtocal(ebcAddress).getChanllengePledgeAmount();
        // The pledge required to be transferred by the user is greater than that stipulated in the EBC contract.
        require(msg.value >= pledgeAmount, "UCE_PLEDGEAMOUNT");
        // Obtaining txinfo Validity Proof by EBC
        chanllengeInfos[chanllengeID].responseTxinfo = IORProtocal(ebcAddress).getRespnseHash(_txinfo);
        chanllengeInfos[chanllengeID].pledgeAmount = msg.value;
        chanllengeInfos[chanllengeID].ebcid = _txinfo.ebcid;
        // Change the corresponding chanllengeInfos state to waiting for maker
        chanllengeInfos[chanllengeID].chanllengeState = 1;
        // chanllengeInfos's stopTime is the current time plus the maxDisputeTime.
        chanllengeInfos[chanllengeID].stopTime =
            block.timestamp +
            getChainInfoByChainID(_txinfo.chainID).maxDisputeTime;
        // The pledge transferred by the user is included in the total pledge.
        chanllengePleged += msg.value;
        emit LogChanllengeInfo(chanllengeID, chanllengeState.ACTION);
    }

    // LPStop
    function USER_LPStop(
        uint256 sourceChain,
        address tokenAddress,
        uint256 ebcid
    ) internal {
        address manager = getManagerAddress();
        OperationsLib.tokenInfo memory _dTinfo = IORManager(manager).getTokenInfo(sourceChain, tokenAddress);
        OperationsLib.chainDeposit storage _cDinfo = chainDeposit[sourceChain][_dTinfo.mainTokenAddress];

        address ebcAddress = IORManager(manager).getEBC(ebcid);
        require(ebcAddress != address(0), "USER_LPStop_EBCADDRESS_0");
        uint256 stopDelayTime = IORProtocal(ebcAddress).getStopDealyTime(sourceChain);

        bytes32[] memory lpids = _cDinfo.lpids;
        // Stop
        if (lpids.length != 0) {
            for (uint256 i = 0; i < lpids.length; i++) {
                //Determine whether it is in Action or Pause state
                if (lpInfo[lpids[i]].startTime != 0 || lpInfo[lpids[i]].stopTime != 0) {
                    lpInfo[lpids[i]].startTime = 0;
                    lpInfo[lpids[i]].stopTime = 0;
                }
                emit LogLpInfoSys(lpids[i], lpState.USERSTOP, 0);
            }
            delete _cDinfo.lpids;
            _cDinfo.useLimit = 0;
            //TODO: The funds of the maker that are released through the user's appeal must have a blocking period, and the maker cannot withdraw directly.
            usedDeposit[_dTinfo.mainTokenAddress] -= _cDinfo.depositAmount;
            _cDinfo.depositAmount = 0;
            //Set Maker withdrawal time to the current time plus stopDelayTime.
            USER_LPStopDelayTime[tokenAddress] = block.timestamp + stopDelayTime;
        }
    }

    // userWithDraw
    function userWithDraw(OperationsLib.txInfo memory _userTx, OperationsLib.lpInfo memory _lpinfo) external {
        bytes32 chanllengeID = OperationsLib.getChanllengeID(_userTx);
        address manager = getManagerAddress();
        // When the state of chanllengeInfos is 'waiting for maker' and the stopTime of chanllengeInfos has passed, the user can withdraw money.
        require(_userTx.sourceAddress == msg.sender, "UW_SENDER");
        require(chanllengeInfos[chanllengeID].chanllengeState == 1, "UW_WITHDRAW");
        require(block.timestamp > chanllengeInfos[chanllengeID].stopTime, "UW_TIME");

        address ebcAddress = IORManager(manager).getEBC(chanllengeInfos[chanllengeID].ebcid);
        require(ebcAddress != address(0), "UW_EBCADDRESS_0");
        uint256 withDrawAmount = 0;
        // Get the unUsed balance corresponding to tokenAddress.
        uint256 unUsedAmount = idleAmount(_userTx.tokenAddress);
        // Calculate the penalty (paid at a specific rate of principal)
        if (_userTx.tokenAddress != address(0)) {
            withDrawAmount = IORProtocal(ebcAddress).getTokenPunish(_userTx.amount);
        } else {
            withDrawAmount =
                chanllengeInfos[chanllengeID].pledgeAmount +
                IORProtocal(ebcAddress).getETHPunish(_userTx.amount);
        }
        // When withDrawAmount is greater than unUsedAmount, it indicates that the available funds are insufficient and will trigger the mandatory stop of all LPs with sourceChain as lpinfo.sourceChain.
        if (withDrawAmount > unUsedAmount) {
            USER_LPStop(_lpinfo.sourceChain, _lpinfo.sourceTAddress, _lpinfo.ebcid);
        }
        // withDraw
        if (_userTx.tokenAddress != address(0)) {
            uint256 withDrawPledge = chanllengeInfos[chanllengeID].pledgeAmount;
            IERC20(_userTx.tokenAddress).transfer(msg.sender, withDrawAmount);
            payable(msg.sender).transfer(withDrawPledge);
        } else {
            payable(msg.sender).transfer(withDrawAmount);
        }
        // Subtract the pledge money transferred by the user challenge from the total pledge money.
        chanllengePleged -= chanllengeInfos[chanllengeID].pledgeAmount;
        emit LogChanllengeInfo(chanllengeID, chanllengeState.WITHDRAWED);
    }

    // makerChanllenger
    // maker responds to arbitration request
    function makerChanllenger(
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
        bytes32[] memory _makerProof
    ) external onlyOwner {
        address manager = getManagerAddress();
        // Get the corresponding chanllengeID through txinfo.
        bytes32 chanllengeID = OperationsLib.getChanllengeID(_userTx);
        // The corresponding chanllengeInfo is required to be in a waiting for maker state.
        require(chanllengeInfos[chanllengeID].chanllengeState == 1, "MC_ANSWER");
        address ebcAddress = IORManager(manager).getEBC(chanllengeInfos[chanllengeID].ebcid);
        // userTx,makerTx and makerProof are provided to EBC and verified to pass
        require(IORProtocal(ebcAddress).checkMakerChallenge(_userTx, _makerTx, _makerProof), "MC_ERROR");
        // Obtaining _makerTx Validity Proof by EBC
        bytes32 makerResponse = keccak256(
            abi.encodePacked(
                _makerTx.lpid,
                _makerTx.chainID,
                _makerTx.sourceAddress,
                _makerTx.destAddress,
                _makerTx.responseAmount,
                _makerTx.tokenAddress
            )
        );
        // The proof of validity of userTx is required to be consistent with that of makerTx.
        require(chanllengeInfos[chanllengeID].responseTxinfo == makerResponse, "MCE_UNMATCH");
        // Change the corresponding chanllengeInfos state to maker success
        chanllengeInfos[chanllengeID].chanllengeState = 2;
        // Subtract the pledge money transferred by the user challenge from the total pledge money.
        chanllengePleged -= chanllengeInfos[chanllengeID].pledgeAmount;

        emit LogChanllengeInfo(chanllengeID, chanllengeState.RESPONSED);
    }
}
