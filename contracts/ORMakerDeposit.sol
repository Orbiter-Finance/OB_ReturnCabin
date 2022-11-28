// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
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
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "hardhat/console.sol";

contract ORMakerDeposit is IORMakerDeposit, Initializable, OwnableUpgradeable {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;

    address public makerFactory;
    // pairId->lpPairInfo
    mapping(bytes32 => OperationsLib.lpPairInfo) public lpInfo;

    // challengeInfos
    mapping(bytes32 => OperationsLib.challengeInfo) private challengeInfos;

    // After the User forcibly stops LP, Maker delays the withdrawal time.
    mapping(address => uint256) public pledgeTokenLPStopDealyTime;

    // challenge pleged eth amount
    uint256 public challengePleged;

    // pledgeToken=> amount
    EnumerableMap.AddressToUintMap private pledgeBalance;
    // chainID => pledgeToken => amount
    mapping(uint256 => EnumerableMap.AddressToUintMap) private chainPledgeBalance;
    // chainID => pairs
    mapping(uint256 => EnumerableSet.Bytes32Set) private chainPairs;
    // pledgeToken => pairs
    mapping(address => EnumerableSet.Bytes32Set) private pledgeTokenPairs;

    function initialize(address _owner, address _makerFactory) public initializer {
        require(_owner != address(0), "Owner address error");
        require(_makerFactory != address(0), "makerFactory address error");
        makerFactory = _makerFactory;
        _transferOwnership(_owner);
    }

    function getPledgeBalanceByChainToken(uint256 _chainId, address _tokenAddress) external view returns (uint256) {
        (, uint256 value) = chainPledgeBalance[_chainId].tryGet(_tokenAddress);
        return value;
    }

    function pairExist(uint256 chainId, bytes32 pairId) external view returns (bool) {
        return chainPairs[chainId].contains(pairId);
    }

    function pairExist(address pledgeToken, bytes32 pairId) external view returns (bool) {
        return pledgeTokenPairs[pledgeToken].contains(pairId);
    }

    function getPledgeBalance(address _tokenAddress) external view returns (uint256) {
        (, uint256 value) = pledgeBalance.tryGet(_tokenAddress);
        return value;
    }

    function getPairsByPledgeToken(address _token) external view returns (bytes32[] memory) {
        return pledgeTokenPairs[_token].values();
    }

    function getPairsByChain(uint256 _chainId) external view returns (bytes32[] memory) {
        return chainPairs[_chainId].values();
    }

    function getManagerAddress() internal view returns (address) {
        return IORMakerV1Factory(makerFactory).manager();
    }

    function getEBCAddress(uint256 ebcid) internal view returns (address) {
        address manager = getManagerAddress();
        address ebcAddress = IORManager(manager).ebc(ebcid);
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
        uint256 pledged = this.getPledgeBalance(tokenAddress);
        uint256 idleamount = balance - pledged - challengePleged;
        return idleamount;
    }

    function getDepositTokenInfo(uint256 chainId, address token)
        internal
        view
        returns (OperationsLib.tokenInfo memory)
    {
        address manager = getManagerAddress();
        return IORManager(manager).getTokenInfo(chainId, token);
    }

    function getSpvAddress() internal view returns (address) {
        address manager = getManagerAddress();
        address spvAddress = IORManager(manager).spv();
        require(spvAddress != address(0), "SPV_NOT_INSTALL");
        return spvAddress;
    }

    function calcLpPledgeAmount(OperationsLib.calcLpNeedPledgeAmountParams[] calldata _lpinfos)
        external
        view
        returns (OperationsLib.lpPledgeCalculate[] memory, uint256 totalPledgeValue)
    {
        OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(_lpinfos[0].fromChain, _lpinfos[0].fromToken);
        address manager = getManagerAddress();
        uint256 maxNum = 0;
        address pledgedToken = depositToken.mainTokenAddress;
        OperationsLib.lpPledgeCalculate[] memory pledgeData = new OperationsLib.lpPledgeCalculate[](_lpinfos.length);
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            OperationsLib.calcLpNeedPledgeAmountParams memory _lpinfo = _lpinfos[i];
            depositToken = getDepositTokenInfo(_lpinfo.fromChain, _lpinfo.fromToken);
            require(depositToken.mainTokenAddress == pledgedToken, "LP that does not support multiple pledge tokens");
            address ebcAddress = IORManager(manager).ebc(_lpinfo.ebcId);
            OperationsLib.chainInfo memory souceChainInfo = IORManager(manager).getChainInfoByChainID(
                _lpinfo.fromChain
            );
            (uint256 baseValue, uint256 additiveValue) = IORProtocal(ebcAddress).getPledgeAmount(
                souceChainInfo.batchLimit,
                _lpinfo.maxPrice
            );
            bool isExists = false;
            for (uint256 j = 0; j < pledgeData.length; j++) {
                if (pledgeData[j].chainId == _lpinfo.fromChain) {
                    isExists = true;
                    pledgeData[j].pledgeValue = Math.max(pledgeData[j].pledgeValue, baseValue + additiveValue);
                    break;
                }
            }
            if (!isExists) {
                pledgeData[maxNum] = OperationsLib.lpPledgeCalculate(
                    _lpinfo.fromChain,
                    baseValue,
                    additiveValue,
                    0,
                    baseValue + additiveValue
                );
                maxNum++;
            }
        }
        OperationsLib.lpPledgeCalculate[] memory returnPledgeData = new OperationsLib.lpPledgeCalculate[](maxNum);
        for (uint256 i = 0; i < pledgeData.length; i++) {
            if (pledgeData[i].chainId != 0) {
                returnPledgeData[i] = pledgeData[i];
                returnPledgeData[i].pledged = this.getPledgeBalanceByChainToken(
                    returnPledgeData[i].chainId,
                    pledgedToken
                );
                // If the SourceChain has been opened, no pledge deposit will be charged
                if (returnPledgeData[i].pledgeValue > returnPledgeData[i].pledged) {
                  totalPledgeValue+=returnPledgeData[i].pledgeValue-returnPledgeData[i].pledged;
                }
            }
        }

        return (returnPledgeData, totalPledgeValue);
    }

    function lpAction(OperationsLib.lpInfo[] calldata _lpinfos, bytes32[][] calldata pairProof)
        external
        payable
        onlyOwner
    {
        require(_lpinfos.length > 0, "Inconsistent Array Length");
        require(_lpinfos.length == pairProof.length, "Inconsistent Array Length");
        OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(
            _lpinfos[0].sourceChain,
            _lpinfos[0].sourceTAddress
        );
        address pledgedToken = depositToken.mainTokenAddress;

        OperationsLib.calcLpNeedPledgeAmountParams[]
            memory calcLpNeedPledgeAmountParams = new OperationsLib.calcLpNeedPledgeAmountParams[](_lpinfos.length);
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            calcLpNeedPledgeAmountParams[i] = OperationsLib.calcLpNeedPledgeAmountParams(
                "",
                _lpinfos[i].sourceChain,
                _lpinfos[i].sourceTAddress,
                _lpinfos[i].ebcid,
                _lpinfos[i].maxPrice
            );
        }
        (OperationsLib.lpPledgeCalculate[] memory pledgeCalcData, uint256 totalPledgeQuantity) = this
            .calcLpPledgeAmount(calcLpNeedPledgeAmountParams);

        address manager = getManagerAddress();
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            require(_lpinfo.minPrice <= _lpinfo.maxPrice, "Illegal minPrice maxPrice value");
            bytes32 pairId = OperationsLib.getPairID(_lpinfo);
            require(
                IORManager(manager).isSupportChain(_lpinfo.sourceChain, _lpinfo.sourceTAddress),
                "Chain Not Supported"
            );
            require(IORManager(manager).isSupportPair(pairId, pairProof[i]), "Pair Not Supported");
            require(!this.pairExist(_lpinfo.sourceChain, pairId), "Pair already exists");
            // first init lpPair
            require(lpInfo[pairId].startTime == 0 && lpInfo[pairId].stopTime == 0, "LPACTION_LPID_UNSTOP");
            uint256 sourceChain = _lpinfo.sourceChain;
            depositToken = getDepositTokenInfo(_lpinfo.sourceChain, _lpinfo.sourceTAddress);
            require(depositToken.mainTokenAddress == pledgedToken, "LP that does not support multiple pledge tokens");
            address ebcAddress = IORManager(manager).ebc(_lpinfo.ebcid);
            require(ebcAddress != address(0), "LPACTION_EBCADDRESS_0");
            // chain add pair
            chainPairs[sourceChain].add(pairId);
            pledgeTokenPairs[pledgedToken].add(pairId);
            // change global lpInfo
            lpInfo[pairId].startTime = block.timestamp;
            lpInfo[pairId].lpId = OperationsLib.getLpID(
                pairId,
                address(this),
                _lpinfo.startTime,
                _lpinfo.minPrice,
                _lpinfo.maxPrice
            );
            emit LogLPAction(pairId, lpInfo[pairId].lpId, _lpinfo);
        }
        // valid
        if (totalPledgeQuantity > 0) {
            (, uint256 pledgedValue) = pledgeBalance.tryGet(pledgedToken);
            for (uint256 i = 0; i < pledgeCalcData.length; i++) {
                // save 1
                uint addPledgedValue = (pledgeCalcData[i].pledgeValue - pledgeCalcData[i].pledged);
                pledgedValue += addPledgedValue;
                // save 2
                uint256 chainId = pledgeCalcData[i].chainId;
                EnumerableMap.AddressToUintMap storage chainPledgeTokenBalance = chainPledgeBalance[chainId];
                (, uint256 tokenValue) = chainPledgeTokenBalance.tryGet(pledgedToken);
                chainPledgeTokenBalance.set(pledgedToken, tokenValue + addPledgedValue);
            }
            pledgeBalance.set(pledgedToken, pledgedValue);
            if (pledgedToken == address(0)) {
                //  int256 AssessmentAmount = int256(supplement) - int256(unUsedAmount - msg.value);
                require(msg.value >= totalPledgeQuantity, "Insufficient pledge quantity");
            } else {
                if (totalPledgeQuantity > 0) {
                    uint256 allowance = IERC20(pledgedToken).allowance(msg.sender, address(this));
                    require(allowance >= totalPledgeQuantity, "Token Insufficient pledge quantity");
                    IERC20(pledgedToken).transferFrom(msg.sender, address(this), totalPledgeQuantity);
                    //
                }
            }
        }
    }

    // LPPause
    function lpPause(OperationsLib.lpInfo[] calldata _lpinfos) external onlyOwner {
        address manager = getManagerAddress();
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            // calc root Hash
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            bytes32 pairId = OperationsLib.getPairID(_lpinfo);
            require(lpInfo[pairId].lpId != "", "LPPAUSE_LPID_UNUSED");
            require(this.pairExist(_lpinfo.sourceChain, pairId), "Pair does not exist");
            require(lpInfo[pairId].startTime != 0 && lpInfo[pairId].stopTime == 0, "LPPAUSE_LPID_UNACTION");
            address ebcAddress = IORManager(manager).ebc(_lpinfo.ebcid);
            require(ebcAddress != address(0), "LPPAUSE_EBCADDRESS_0");
            uint256 stopDelayTime = getChainInfoByChainID(_lpinfo.sourceChain).stopDelayTime;
            lpInfo[pairId].stopTime = block.timestamp + stopDelayTime;
            lpInfo[pairId].startTime = 0;
            emit LogLPPause(pairId, lpInfo[pairId].lpId, _lpinfo);
        }
    }

    function lpRestart(OperationsLib.lpRestart[] calldata _lps) external onlyOwner {
        for (uint256 i = 0; i < _lps.length; i++) {
            OperationsLib.lpRestart memory _item = _lps[i];
            bytes32 pairId = _item.pid;
            bytes32 lpId = _item.lpid;
            require(lpInfo[pairId].lpId != "", "LPPAUSE_LPID_UNUSED");
            require(lpInfo[pairId].lpId == lpId, "LPPAUSE_LPID_ERROR");
            require(lpInfo[pairId].startTime == 0 && lpInfo[pairId].stopTime != 0, "LPUPDATE_NOTPAUSED");
            lpInfo[pairId].startTime = block.timestamp;
            lpInfo[pairId].stopTime = 0;
            emit LogLPRestart(pairId, lpId, _item.gasFee,  _item.tradingFee);
        }
    }

    // LPStop
    function lpStop(OperationsLib.lpInfo[] calldata _lpinfos) external onlyOwner {
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            bytes32 pairId = OperationsLib.getPairID(_lpinfo);
            require(lpInfo[pairId].lpId != "", "LPPAUSE_LPID_UNUSED");
            require(lpInfo[pairId].startTime == 0 && lpInfo[pairId].stopTime != 0, "LPSTOP_LPID_UNPAUSE");
            require(block.timestamp > lpInfo[pairId].stopTime, "LPSTOP_LPID_TIMEUNABLE");
            OperationsLib.tokenInfo memory depositToken = getDepositTokenInfo(
                _lpinfo.sourceChain,
                _lpinfo.sourceTAddress
            );
            lpInfo[pairId].stopTime = 0;
            uint256 chainId = _lpinfo.sourceChain;
            require(this.pairExist(chainId, pairId), "Pair does not exist");
            address pledgedToken = depositToken.mainTokenAddress;
            bool success = chainPairs[chainId].remove(pairId);
            require(success, "Remove chainPairs Fail");
            success = pledgeTokenPairs[pledgedToken].remove(pairId);
            require(success, "Remove PledgeTokenPairs Fail");
            if (chainPairs[chainId].length() <= 0) {
                EnumerableMap.AddressToUintMap storage chainPledgeTokenBalance = chainPledgeBalance[chainId];
                for (uint256 j = 0; j < chainPledgeTokenBalance.length(); j++) {
                    (address token, uint256 chainTokenValue) = chainPledgeTokenBalance.at(j);
                    chainPledgeTokenBalance.remove(token);
                    (, uint256 value) = pledgeBalance.tryGet(pledgedToken);
                    require(value >= chainTokenValue, "chainPledgeTokenBalance gt pledgeBalance");
                    //
                    pledgeBalance.set(pledgedToken, value - chainTokenValue);
                }
            }
            emit LogLPStop(pairId, lpInfo[pairId].lpId, _lpinfo);
        }
    }

    // LPUpdate
    function lpUpdate(OperationsLib.lpChange[] calldata _lpinfos) external onlyOwner {
        for (uint256 i = 0; i < _lpinfos.length; i++) {
            OperationsLib.lpChange memory _changeRow = _lpinfos[i];
            bytes32 pairId = _changeRow.pid;
            bytes32 lpId = _changeRow.lpid;
            require(lpInfo[pairId].lpId != "", "LPPAUSE_LPID_UNUSED");
            require(lpInfo[pairId].lpId == lpId, "LPPAUSE_LPID_ERROR");
            require(lpInfo[pairId].startTime == 0 && lpInfo[pairId].stopTime != 0, "LPUPDATE_NOTPAUSED");
            emit LogLPUpdate(pairId, lpId, _changeRow.gasFee, _changeRow.tradingFee);
        }
    }

    // withDrawAssert()
    function withDrawAssert(uint256 amount, address tokenAddress) external onlyOwner {
        // This condition is not passed only when the user withdrawals trigger a forced stop event.
        require(block.timestamp >= pledgeTokenLPStopDealyTime[tokenAddress], "WITHDRAW_NOTIME");
        require(amount != 0, "WITHDRAW_ILLEGALAMOUNT");
        require(challengePleged == 0, "WITHDRAW_NOCHANLLENGE");
        uint256 unUsedAmount = idleAmount(tokenAddress);
        require(amount <= unUsedAmount, "WITHDRAW_INSUFFICIENT_AMOUNT");
        // Cancellation of Maker withdrawal time limit
        if (pledgeTokenLPStopDealyTime[tokenAddress] != 0) {
            pledgeTokenLPStopDealyTime[tokenAddress] = 0;
        }
        if (tokenAddress != address(0)) {
            IERC20(tokenAddress).transfer(msg.sender, amount);
        } else {
            payable(msg.sender).transfer(amount);
        }
    }

    // userChallenge
    // User Initiates Arbitration Request
    function userChallenge(OperationsLib.txInfo memory _txinfo, bytes32[] memory _txproof) external payable {
        address ebcAddress = getEBCAddress(_txinfo.ebcid);
        // Determine whether sourceAddress in txinfo is consistent with the caller's address
        require(_txinfo.sourceAddress == _msgSender(), "UCE_SENDER");
        // Determine whether destAddress in txinfo is an MDC address
        require(_txinfo.destAddress == owner(), "UCE_4");
        // Verify whether it is within the period of appeal
        require(block.timestamp > _txinfo.timestamp + getChainInfoByChainID(_txinfo.chainID).maxReceiptTime, "UCE_5");

        // txinfo and txproof are provided to EBC and verified to pass
        require(IORProtocal(ebcAddress).checkUserChallenge(_txinfo, _txproof), "UC_ERROR");
        // Get the corresponding challengeID through txinfo.
        bytes32 challengeID = OperationsLib.getChallengeID(_txinfo);
        // The corresponding challengeInfo is required to be in an unused state.
        require(challengeInfos[challengeID].challengeState == 0, "UCE_USED");
        uint256 pledgeAmount = IORProtocal(ebcAddress).challengePledgedAmount();
        // The pledge required to be transferred by the user is greater than that stipulated in the EBC contract.
        require(msg.value >= pledgeAmount, "UCE_PLEDGEAMOUNT");
        // Obtaining txinfo Validity Proof by EBC
        challengeInfos[challengeID].responseTxinfo = IORProtocal(ebcAddress).getRespnseHash(_txinfo);
        challengeInfos[challengeID].pledged = msg.value;
        challengeInfos[challengeID].token = _txinfo.tokenAddress;
        challengeInfos[challengeID].value = _txinfo.amount;
        challengeInfos[challengeID].ebcid = _txinfo.ebcid;
        // Change the corresponding challengeInfos state to waiting for maker
        challengeInfos[challengeID].challengeState = 1;
        // challengeInfos's stopTime is the current time plus the maxDisputeTime.
        uint256 maxDisputeTime = getChainInfoByChainID(_txinfo.chainID).maxDisputeTime;
        challengeInfos[challengeID].stopTime = block.timestamp + maxDisputeTime;
        challengeInfos[challengeID].endTime = block.timestamp + maxDisputeTime + maxDisputeTime;

        // The pledge transferred by the user is included in the total pledge.
        challengePleged += msg.value;
        emit LogChallengeInfo(address(this), challengeID, challengeInfos[challengeID], _txinfo);
    }

    // LPStop
    function lpUserStop(
        uint256 sourceChain,
        address sourceToken,
        uint256 ebcid
    ) internal {
        address manager = getManagerAddress();
        OperationsLib.tokenInfo memory tokenInfo = getDepositTokenInfo(sourceChain, sourceToken);
        address ebcAddress = IORManager(manager).ebc(ebcid);
        require(ebcAddress != address(0), "USER_LPStop_EBCADDRESS_0");
        address pledgedToken = tokenInfo.mainTokenAddress;
        uint256 stopDelayTime = getChainInfoByChainID(sourceChain).stopDelayTime;
        // is exists
        if (chainPairs[sourceChain].length() > 0) {
            bytes32[] memory pairs = this.getPairsByChain(sourceChain);
            for (uint256 i = 0; i < pairs.length; i++) {
                bytes32 pairId = pairs[i];
                require(this.pairExist(sourceChain, pairId), "Pair does not exist");
                bool success = chainPairs[sourceChain].remove(pairId);
                require(success, "Remove chainPairs Fail");
                success = pledgeTokenPairs[pledgedToken].remove(pairId);
                require(success, "Remove chainPairs Fail");
                // if (lpInfo[pairs[i]].startTime != 0 || lpInfo[pairs[i]].stopTime != 0) {
                lpInfo[pairs[i]].startTime = 0;
                lpInfo[pairs[i]].stopTime = 0;
                // }
                emit LogLPUserStop(pairs[i], lpInfo[pairs[i]].lpId);
            }
            EnumerableMap.AddressToUintMap storage chainPledgeTokenBalance = chainPledgeBalance[sourceChain];
            (, uint256 pledgedTokenValue) = chainPledgeTokenBalance.tryGet(pledgedToken);
            // Release all deposits
            bool removed = chainPledgeBalance[sourceChain].remove(pledgedToken);
            require(removed, "Remove chainPledgeBalance Fail");
            (, uint256 pledgedValue) = pledgeBalance.tryGet(pledgedToken);
            pledgeBalance.set(pledgedToken, pledgedValue - pledgedTokenValue);
        }
        //     //Set Maker withdrawal time to the current time plus stopDelayTime.
        pledgeTokenLPStopDealyTime[pledgedToken] = block.timestamp + stopDelayTime;
    }

    function makerChallengeFail(bytes32 challengeID) internal returns (bool) {
        OperationsLib.challengeInfo storage challengeInfo = challengeInfos[challengeID];
        address manager = getManagerAddress();
        address ebcAddress = IORManager(manager).ebc(challengeInfo.ebcid);
        require(ebcAddress != address(0), "UW_EBCADDRESS_0");
        // Get the unUsed balance corresponding to tokenAddress.
        uint256 unUsedAmount = idleAmount(challengeInfo.token);
        // Calculate the penalty (paid at a specific rate of principal)
        (uint256 baseValue, uint256 additiveValue) = IORProtocal(ebcAddress).calculateCompensation(
            challengeInfo.token,
            challengeInfo.value
        );
        uint256 withDrawAmount = baseValue + additiveValue;
        // When withDrawAmount is greater than unUsedAmount, it indicates that the available funds are insufficient and will trigger the mandatory stop of all LPs with sourceChain as lpinfo.sourceChain.
        challengeInfo.endTime = block.timestamp;
        challengeInfo.challengeState = 3;

        uint256 pledgeAmount = challengeInfo.pledged;
        require(challengePleged >= pledgeAmount, "ChallengePleged Insufficient balance");
        challengePleged -= pledgeAmount;
        // Subtract the pledge money transferred by the user challenge from the total pledge money.
        if (challengeInfo.token != address(0)) {
            require(unUsedAmount >= withDrawAmount, "Insufficient balance");
            IERC20(challengeInfo.token).transfer(msg.sender, withDrawAmount);
            require(address(this).balance >= pledgeAmount, "Insufficient balance");
            payable(msg.sender).transfer(pledgeAmount);
            return true;
        } else {
            uint256 totalValue = withDrawAmount + pledgeAmount;
            require(unUsedAmount >= totalValue, "Insufficient balance");
            require(address(this).balance >= totalValue, "Insufficient balance");
            payable(msg.sender).transfer(totalValue);
            return true;
        }
    }

    // userWithDraw
    function userWithDraw(OperationsLib.txInfo memory _userTx, OperationsLib.lpInfo memory _lpinfo) external {
        bytes32 challengeID = OperationsLib.getChallengeID(_userTx);
        address manager = getManagerAddress();
        // When the state of challengeInfos is 'waiting for maker' and the stopTime of challengeInfos has passed, the user can withdraw money.
        require(_userTx.sourceAddress == msg.sender, "UW_SENDER");
        OperationsLib.challengeInfo storage challengeInfo = challengeInfos[challengeID];
        require(challengeInfo.challengeState == 1, "UW_WITHDRAW");
        require(block.timestamp > challengeInfo.stopTime, "UW_TIME");
        bytes32 pairId = OperationsLib.getPairID(_lpinfo);
        require(this.pairExist(_lpinfo.sourceChain, pairId), "Pair does not exist");
        address ebcAddress = IORManager(manager).ebc(challengeInfo.ebcid);
        require(ebcAddress != address(0), "UW_EBCADDRESS_0");
        // Get the unUsed balance corresponding to tokenAddress.
        uint256 unUsedAmount = idleAmount(challengeInfo.token);
        // Calculate the penalty (paid at a specific rate of principal)
        (uint256 baseValue, uint256 additiveValue) = IORProtocal(ebcAddress).calculateCompensation(
            challengeInfo.token,
            challengeInfo.value
        );
        uint256 withDrawAmount = baseValue + additiveValue;
        // When withDrawAmount is greater than unUsedAmount, it indicates that the available funds are insufficient and will trigger the mandatory stop of all LPs with sourceChain as lpinfo.sourceChain.
        challengeInfo.endTime = block.timestamp;
        challengeInfo.challengeState = 3;

        uint256 pledgeAmount = challengeInfo.pledged;
        require(challengePleged >= pledgeAmount, "ChallengePleged Insufficient balance");
        challengePleged -= pledgeAmount;
        // Subtract the pledge money transferred by the user challenge from the total pledge money.
        if (challengeInfo.token != address(0)) {
            if (withDrawAmount > unUsedAmount) {
                lpUserStop(_lpinfo.sourceChain, challengeInfo.token,challengeInfo.ebcid);
            }
            IERC20(challengeInfo.token).transfer(msg.sender, withDrawAmount);
            require(address(this).balance >= pledgeAmount, "Insufficient balance");
            payable(msg.sender).transfer(pledgeAmount);
        } else {
            uint256 totalValue = withDrawAmount + pledgeAmount;
            if (totalValue > unUsedAmount) {
                lpUserStop(_lpinfo.sourceChain, challengeInfo.token,challengeInfo.ebcid);
            }
            require(address(this).balance >= totalValue, "Insufficient balance");
            payable(msg.sender).transfer(totalValue);
        }
        emit LogChallengeInfo(address(this), challengeID, challengeInfo, _userTx);
    }

    // makerChllenger MakeGood
    function challengerMakeGood(bytes32 challengeID) external onlyOwner {
        require(challengeInfos[challengeID].challengeState == 1, "MC_ANSWER");
        require(block.timestamp > challengeInfos[challengeID].endTime, "UW_TIME");
        //
        bool success = makerChallengeFail(challengeID);
        require(success, "MakerChallenge Fail");
        challengeInfos[challengeID].challengeState = 3;

        emit LogChallengerMakeGood(address(this), challengeID, challengeInfos[challengeID]);
    }

    // maker responds to arbitration request
    function makerChallenger(
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
        bytes32[] memory _makerProof
    ) external onlyOwner {
        address manager = getManagerAddress();
        // Get the corresponding challengeID through txinfo.
        bytes32 challengeID = OperationsLib.getChallengeID(_userTx);
        // The corresponding challengeInfo is required to be in a waiting for maker state.
        require(challengeInfos[challengeID].challengeState == 1, "MC_ANSWER");
        // Change the corresponding challengeInfos state to maker success
        challengeInfos[challengeID].challengeState = 2;
        challengeInfos[challengeID].endTime = block.timestamp;
        address ebcAddress = IORManager(manager).ebc(challengeInfos[challengeID].ebcid);
        // Determine whether sourceAddress in txinfo is an MDC address
        require(_makerTx.sourceAddress == msg.sender, "MC_SENDER");
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
                _makerTx.responseSafetyCode,
                _makerTx.tokenAddress
            )
        );
        // The proof of validity of userTx is required to be consistent with that of makerTx.
        require(challengeInfos[challengeID].responseTxinfo == makerResponse, "MCE_UNMATCH");
        // Subtract the pledge money transferred by the user challenge from the total pledge money.
        challengePleged -= challengeInfos[challengeID].pledged;
        emit LogChallengeInfo(address(this), challengeID, challengeInfos[challengeID], _makerTx);
    }
}
