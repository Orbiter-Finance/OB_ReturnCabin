// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./interface/IORMakerDeposit.sol";
import "./library/Operation.sol";
import "./interface/IORManager.sol";
import "./interface/IORProtocal.sol";
import "./interface/IERC20.sol";
import "hardhat/console.sol";
import "./interface/IORMakerV1Factory.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./Multicall.sol";

interface IProventh {
    function startValidate(
        OperationsLib.ValidateParams calldata params
    ) external view returns (OperationsLib.ValidateResult memory r);
}

contract ORMakerDeposit is IORMakerDeposit, Multicall {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    

    // challenge pleged eth amount
    uint256 public challengePleged;
    IORMakerV1Factory public getMakerFactory;
    address public owner;
    // pairId->lpPairInfo
    // mapping(bytes32 => OperationsLib.lpPairInfo) public lpInfo;
    // challengeInfos
    mapping(bytes32 => OperationsLib.challengeInfo) private challengeInfos;
    // After the User forcibly stops LP, Maker delays the withdrawal time.
    mapping(address => uint256) public pledgeTokenLPStopDealyTime;
    // source chainID => pledgeToken => amount
    mapping(uint256 => EnumerableMap.AddressToUintMap) private sourceChainPledgeBalance;
    // source chainID => pairId => amount
    mapping(uint256 => EnumerableMap.Bytes32ToUintMap) private sourceChainPairs;

    // lpId  => LPStruct
    mapping(bytes32 => OperationsLib.LPStruct) public lpData;
    // pairId => EffectivePairStruct
    mapping(bytes32 => OperationsLib.EffectivePairStruct) public effectivePair;
    // lpId => lp Create timestamp
    // EnumerableMap.Bytes32ToUintMap private lpDataMapTimestamp;
    // pledgeToken=> amount
    EnumerableMap.AddressToUintMap private pledgeBalance;
    // pledgeToken => pairs
    // mapping(uint256 => EnumerableSet.Bytes32Set) private pledgeTokenPairs;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function initialize(address _owner) public {
        require(_owner != address(0), "Owner address error");
        getMakerFactory = IORMakerV1Factory(msg.sender);
        owner = _owner;
    }

    function getPledgeBalance(address token) external view returns (uint256) {
        (, uint256 value) = pledgeBalance.tryGet(token);
        return value;
    }

    function getPledgeBalanceByChainToken(uint256 chainId, address token) external view returns (uint256) {
        (, uint256 value) = sourceChainPledgeBalance[chainId].tryGet(token);
        return value;
    }

    function getManager() private view returns (IORManager manager) {
        manager = getMakerFactory.getManager();
    }

    function idleAmount(address token) public view returns (uint256) {
        uint256 balance = 0;
        if (token != address(0)) {
            IERC20 liquidityToken = IERC20(token);
            balance = liquidityToken.balanceOf(address(this));
        } else {
            balance = address(this).balance;
        }
        uint256 pledged = this.getPledgeBalance(token);
        uint256 idleamount = balance - pledged - challengePleged;
        return idleamount;
    }

    function calculatePairPledgeAmount(
        OperationsLib.LPActionStruct[] calldata _lps
    ) external view returns (OperationsLib.CalculatePairPledgeResponseTemp[] memory) {
        OperationsLib.CalculatePairPledgeResponseTemp[]
            memory tempData = new OperationsLib.CalculatePairPledgeResponseTemp[](_lps.length);
        IORManager manager = getManager();
        OperationsLib.CalculatePairPledgeResponse[] memory pledgePairListData = manager.calculatePairPledgeAmount(_lps);
        require(_lps.length == pledgePairListData.length, "Array inconsistent");
        uint count;
        for (uint256 i = 0; i < _lps.length; ) {
            OperationsLib.CalculatePairPledgeResponse memory _pairPledge = pledgePairListData[i];
            OperationsLib.LPActionStruct calldata _lp = _lps[i];
            address pledgedToken = pledgePairListData[i].pledgedToken;
            (uint sourceChain, , , , ) = manager.getPairs(_lp.pairId);
            // pledged
            if (_pairPledge.pledgedValue > 0) {
                bool isExist;
                for (uint256 j = 0; j < tempData.length; ) {
                    OperationsLib.CalculatePairPledgeResponseTemp memory tempItem = tempData[j];
                    if (
                        tempItem.chainId != 0 &&
                        tempItem.pledgedToken == pledgedToken &&
                        tempItem.chainId == sourceChain
                    ) {
                        isExist = true;
                        if (_pairPledge.pledgedValue > tempItem.pledgedValue) {
                            tempItem.pledgedValue = _pairPledge.pledgedValue;
                        }
                        break;
                    }
                    unchecked {
                        ++j;
                    }
                }
                if (!isExist) {
                    tempData[count] = OperationsLib.CalculatePairPledgeResponseTemp(
                        pledgedToken,
                        sourceChain,
                        _pairPledge.pledgedValue
                    );
                    count++;
                }
            }
            unchecked {
                ++i;
            }
        }
        uint256 accordWithCount = tempData.length - count;
        if (accordWithCount > 0) {
            assembly {
                mstore(tempData, sub(mload(tempData), accordWithCount))
            }
        }
        for (uint i=0;i<tempData.length;) {
            uint256 nowPledgedValue = this.getPledgeBalanceByChainToken(tempData[i].chainId, tempData[i].pledgedToken);
            if (tempData[i].pledgedValue>nowPledgedValue) {
                tempData[i].pledgedValue = tempData[i].pledgedValue - nowPledgedValue;
            } else {
                tempData[i].pledgedValue = 0;
            }
            unchecked {
                ++i;
            }
        }
        return tempData;
    }

    function lpAction(OperationsLib.LPActionStruct[] calldata _lps) external payable onlyOwner {
        IORManager manager = getManager();
        OperationsLib.CalculatePairPledgeResponse[] memory pledgePairListData = manager.calculatePairPledgeAmount(_lps);
        require(_lps.length == pledgePairListData.length, "Array inconsistent");
        uint needPledgeValue = 0;
        address pledgedToken = pledgePairListData[0].pledgedToken;
        for (uint256 i = 0; i < _lps.length; ) {
            OperationsLib.CalculatePairPledgeResponse memory _pairPledge = pledgePairListData[i];
            require(pledgedToken == _pairPledge.pledgedToken, "The pledgedToken is inconsistent");
            OperationsLib.LPActionStruct calldata _lp = _lps[i];
            require(_pairPledge.pairId == _lp.pairId, "The pairId is inconsistent");
            (uint sourceChain, , , , ) = manager.getPairs(_lp.pairId);
            OperationsLib.EffectivePairStruct memory effectivePairItem = effectivePair[_lp.pairId];
            require(effectivePairItem.lpId == 0, "Pair already exists");
            require(effectivePairItem.startTime == 0 && effectivePairItem.stopTime == 0, "LP started");
            bytes32 lpId = OperationsLib.getLpID(
                _lp.pairId,
                address(this),
                block.timestamp,
                _lp.minPrice,
                _lp.maxPrice
            );
            // bool created = sourceChainPairs[sourceChain].add(_lp.pairId);
            // require(created, "Pair already exists");
            bool created = sourceChainPairs[sourceChain].set(_lp.pairId, _pairPledge.pledgedValue);
            require(created, "Pair already exists");

            lpData[lpId] = OperationsLib.LPStruct(
                _lp.pairId,
                _lp.minPrice,
                _pairPledge.maxPrice,
                _lp.gasFee,
                _lp.tradingFee,
                block.timestamp,
                0
            );
            effectivePair[_lp.pairId] = OperationsLib.EffectivePairStruct(lpId, block.timestamp, 0);
            // pledged
            if (_pairPledge.pledgedValue > 0) {
                uint256 nowPledgedValue = this.getPledgeBalanceByChainToken(sourceChain, pledgedToken);
                if (_pairPledge.pledgedValue > nowPledgedValue) {
                    needPledgeValue += _pairPledge.pledgedValue - nowPledgedValue;
                    sourceChainPledgeBalance[sourceChain].set(pledgedToken, _pairPledge.pledgedValue);
                }
            }
            emit LogLPAction(_lp.pairId, lpId, lpData[lpId]);
            unchecked {
                ++i;
            }
        }
        if (needPledgeValue > 0) {
            uint256 unUsedAmount = idleAmount(pledgedToken);
            uint256 pledgedTokenValue = this.getPledgeBalance(pledgedToken);
            pledgeBalance.set(pledgedToken, pledgedTokenValue + needPledgeValue);
            if (needPledgeValue > unUsedAmount) {
                uint256 subunUsedAmount = needPledgeValue - unUsedAmount;
                if (pledgedToken == address(0)) {
                    require(msg.value >= subunUsedAmount, "Insufficient pledge quantity");
                } else {
                    if (needPledgeValue > 0) {
                        uint256 allowance = IERC20(pledgedToken).allowance(msg.sender, address(this));
                        require(allowance >= subunUsedAmount, "Token Insufficient pledge quantity");
                        bool success = IERC20(pledgedToken).transferFrom(msg.sender, address(this), subunUsedAmount);
                        require(success, "TransferFrom Fail");
                    }
                }
            }
        }
    }

    function lpPause(bytes32 pairId) external onlyOwner {
        IORManager manager = getManager();
        OperationsLib.EffectivePairStruct storage effectivePairItem = effectivePair[pairId];
        require(effectivePairItem.lpId != 0, "LP does not exist");
        require(effectivePairItem.startTime != 0 && effectivePairItem.stopTime == 0, "LP not started");
        (uint256 sourceChain, , , , ) = manager.getPairs(pairId);
        (, , , , , uint256 stopDelayTime, ) = manager.getChain(sourceChain);
        effectivePairItem.stopTime = block.timestamp + stopDelayTime;
        effectivePairItem.startTime = 0;
        // emit LogLPPause(pairId, lpInfo[pairId].lpId, _lpinfo);
    }

    function lpRestart(bytes32 pairId) external onlyOwner {
        OperationsLib.EffectivePairStruct storage effectivePairItem = effectivePair[pairId];
        require(effectivePairItem.lpId != 0, "LP does not exist");
        require(effectivePairItem.startTime == 0 && effectivePairItem.stopTime != 0, "LP not paused");
        effectivePairItem.startTime = block.timestamp;
        effectivePairItem.stopTime = 0;
    }

    // LPStop
    function lpStop(bytes32 pairId) external onlyOwner {
        IORManager manager = getManager();
        OperationsLib.EffectivePairStruct memory effectivePairItem = effectivePair[pairId];
        require(effectivePairItem.startTime == 0 && effectivePairItem.stopTime != 0, "LP not paused");
        require(block.timestamp >= effectivePairItem.stopTime, "Not yet operating time");
        OperationsLib.LPStruct storage lpInfo = lpData[effectivePairItem.lpId];
        (uint256 sourceChain, , address sourceToken, , ) = manager.getPairs(pairId);
        (, uint256 nowPairPledgedValue) = sourceChainPairs[sourceChain].tryGet(pairId);
        bool success = sourceChainPairs[sourceChain].remove(pairId);
        lpInfo.stopTime = block.timestamp;
        delete effectivePair[pairId];
        OperationsLib.TokenInfo memory tokenInfo = manager.getTokenInfo(sourceChain, sourceToken);
        address pledgedToken = tokenInfo.mainTokenAddress;
        uint256 nowSourceChainPledgedValue = this.getPledgeBalanceByChainToken(sourceChain,pledgedToken);
        if (nowPairPledgedValue == nowSourceChainPledgedValue) {
            // find max
            uint256 pledgedValue;
            for (uint256 i=0;i<sourceChainPairs[sourceChain].length();) {
                (, uint256 value) = sourceChainPairs[sourceChain].at(i);
                pledgedValue = value > pledgedValue ? value : pledgedValue;
                unchecked {
                    ++i;
                }
            }
            uint256 subValue = nowSourceChainPledgedValue - pledgedValue;
            if (subValue>0) {
                sourceChainPledgeBalance[sourceChain].set(pledgedToken, nowSourceChainPledgedValue - subValue);
                pledgeBalance.set(pledgedToken, nowSourceChainPledgedValue - subValue);
            }
          
        }
    }

    // LPUpdate
    function lpUpdate(OperationsLib.LPUpdateStruct calldata _lp) external onlyOwner {
        bytes32 pairId = _lp.pairId;
        OperationsLib.EffectivePairStruct storage effectivePairItem = effectivePair[pairId];
        require(effectivePairItem.lpId != 0, "LP does not exist");
        require(effectivePairItem.startTime == 0 && effectivePairItem.stopTime != 0, "LP not paused");
        effectivePairItem.startTime = block.timestamp;
        effectivePairItem.stopTime = 0;
        // change old lp stop time
        OperationsLib.LPStruct storage lpInfo = lpData[effectivePairItem.lpId];
        lpInfo.stopTime = block.timestamp;
        // new lp
        bytes32 lpId = OperationsLib.getLpID(pairId, address(this), block.timestamp, lpInfo.minPrice, lpInfo.maxPrice);
        lpData[lpId] = OperationsLib.LPStruct(
            pairId,
            lpInfo.minPrice,
            lpInfo.maxPrice,
            _lp.gasFee,
            _lp.tradingFee,
            block.timestamp,
            0
        );
        effectivePair[pairId] = OperationsLib.EffectivePairStruct(lpId, block.timestamp, 0);
    }

    function lpUserStop(bytes32 pairId) internal {}

    // LPStop
    function lpUserStop(uint256 sourceChain, address sourceToken, address ebcAddress) internal {
        // IORManager manager = getManager();
        // OperationsLib.TokenInfo memory tokenInfo = manager.getTokenInfo(sourceChain, sourceToken);
        // // address ebcAddress = manager.getEBC(ebcid);
        // require(ebcAddress != address(0), "USER_LPStop_EBCADDRESS_0");
        // address pledgedToken = tokenInfo.mainTokenAddress;
        // (, , , , , uint256 stopDelayTime, ) = getManager().getChain(sourceChain);
        // // is exists
        // if (chainPairs[sourceChain].length() > 0) {
        //     bytes32[] memory pairs = this.getPairsByChain(sourceChain);
        //     for (uint256 i = 0; i < pairs.length; ) {
        //         bytes32 pairId = pairs[i];
        //         require(this.pairExist(sourceChain, pairId), "Pair does not exist");
        //         bool success = chainPairs[sourceChain].remove(pairId);
        //         require(success, "Remove chainPairs Fail");
        //         success = pledgeTokenPairs[pledgedToken].remove(pairId);
        //         require(success, "Remove chainPairs Fail");
        //         lpInfo[pairs[i]].startTime = 0;
        //         lpInfo[pairs[i]].stopTime = 0;
        //         // }
        //         emit LogLPUserStop(pairs[i], lpInfo[pairs[i]].lpId);
        //         unchecked {
        //             ++i;
        //         }
        //     }
        //     EnumerableMap.AddressToUintMap storage chainPledgeTokenBalance = chainPledgeBalance[sourceChain];
        //     (, uint256 pledgedTokenValue) = chainPledgeTokenBalance.tryGet(pledgedToken);
        //     // Release all deposits
        //     bool removed = chainPledgeBalance[sourceChain].remove(pledgedToken);
        //     require(removed, "Remove chainPledgeBalance Fail");
        //     (, uint256 pledgedValue) = pledgeBalance.tryGet(pledgedToken);
        //     bool created = pledgeBalance.set(pledgedToken, pledgedValue - pledgedTokenValue);
        //     require(!created, "PledgeBalance Not Exist");
        // }
        // //     //Set Maker withdrawal time to the current time plus stopDelayTime.
        // pledgeTokenLPStopDealyTime[pledgedToken] = block.timestamp + stopDelayTime;
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
            bool success = IERC20(tokenAddress).transfer(msg.sender, amount);
            require(success, "TransferFrom Fail");
        } else {
            payable(msg.sender).transfer(amount);
            // require(success, "TransferFrom Fail");
        }
    }

    function checkTxProofExists(
        OperationsLib.ValidateParams calldata params
    ) internal view returns (bool, OperationsLib.Transaction memory) {
        IProventh spv = IProventh(getManager().getSPV());
        OperationsLib.ValidateResult memory validResult = spv.startValidate(params);
        require(validResult.result, "startValidate fail");
        bool success = validResult.result;
        OperationsLib.Transaction memory tx = OperationsLib.Transaction(
            bytes32(validResult.txHash),
            bytes32(validResult.blockHash),
            validResult.from,
            validResult.to,
            validResult.nonce,
            validResult.value,
            validResult.gasPrice,
            validResult.gas,
            validResult.chainId,
            validResult.blockNumber,
            0,
            validResult.transactionIndex,
            validResult.input
        );
        return (success, tx);
    }

    // OperationsLib.ValidateParams result =
    // userChallenge
    // User Initiates Arbitration Request
    function userChallenge(OperationsLib.ValidateParams calldata params) external payable {
        // address ebcAddress = getManager().getEBC(_txinfo.ebcid);
        // TODO: get ebc
        (bool success, OperationsLib.Transaction memory _txinfo) = checkTxProofExists(params);
        address ebcAddress = address(0);
        require(success, "UC_ERROR");
        // Determine whether sourceAddress in txinfo is consistent with the caller's address
        require(_txinfo.from == msg.sender, "UCE_SENDER");
        // Determine whether destAddress in txinfo is an MDC address
        require(_txinfo.to == owner, "UCE_4");
        // Verify whether it is within the period of appeal
        (, , , , uint256 maxReceiptTime, , ) = getManager().getChain(_txinfo.chainId);

        require(block.timestamp > _txinfo.timestamp + maxReceiptTime, "UCE_5");
        // txinfo and txproof are provided to EBC and verified to pass
        // Get the corresponding challengeID through txinfo.
        bytes32 challengeID = OperationsLib.getChallengeID(_txinfo);
        // The corresponding challengeInfo is required to be in an unused state.
        require(challengeInfos[challengeID].challengeState == 0, "UCE_USED");
        // uint256 pledgeAmount = IORProtocal(ebcAddress).challengePledgedAmount();
        // The pledge required to be transferred by the user is greater than that stipulated in the EBC contract.
        require(IORProtocal(ebcAddress).checkUserChallenge(_txinfo, msg.value), "checkUserChallenge Fail");
        // Obtaining txinfo Validity Proof by EBC
        challengeInfos[challengeID].responseTxinfo = IORProtocal(ebcAddress).getResponseHash(_txinfo, true);
        challengeInfos[challengeID].pledged = msg.value;
        // TODO: get token addr
        challengeInfos[challengeID].token = address(0);
        // challengeInfos[challengeID].token = _txinfo.tokenAddress;
        challengeInfos[challengeID].value = _txinfo.value;
        challengeInfos[challengeID].ebc = ebcAddress;
        // Change the corresponding challengeInfos state to waiting for maker
        challengeInfos[challengeID].challengeState = 1;
        // challengeInfos's stopTime is the current time plus the maxDisputeTime.
        (, , , uint256 maxDisputeTime, , , ) = getManager().getChain(_txinfo.chainId);
        challengeInfos[challengeID].stopTime = block.timestamp + maxDisputeTime;
        challengeInfos[challengeID].endTime = block.timestamp + maxDisputeTime + maxDisputeTime;

        // The pledge transferred by the user is included in the total pledge.
        challengePleged += msg.value;
        emit LogChallengeInfo(address(getMakerFactory), challengeID, challengeInfos[challengeID], _txinfo);
    }

    // userWithDraw
    function userWithDraw(OperationsLib.Transaction memory _userTx, OperationsLib.lpInfo memory _lpinfo) external {
        bytes32 challengeID = OperationsLib.getChallengeID(_userTx);
        // IORManager manager = getManager();
        // When the state of challengeInfos is 'waiting for maker' and the stopTime of challengeInfos has passed, the user can withdraw money.
        require(_userTx.from == msg.sender, "UW_SENDER");
        OperationsLib.challengeInfo storage challengeInfo = challengeInfos[challengeID];
        require(challengeInfo.challengeState == 1, "UW_WITHDRAW");
        require(block.timestamp > challengeInfo.stopTime, "UW_TIME");
        // bytes32 pairId = OperationsLib.getPairID(_lpinfo);
        // require(this.pairExist(_lpinfo.sourceChain, pairId), "Pair does not exist");
        // address ebcAddress = manager.getEBC(challengeInfo.ebcid);
        address ebcAddress = challengeInfo.ebc;
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
        emit LogChallengerCompensation(
            address(getMakerFactory),
            challengeID,
            baseValue,
            challengeInfo.pledged,
            additiveValue
        );
        // Subtract the pledge money transferred by the user challenge from the total pledge money.
        if (challengeInfo.token != address(0)) {
            if (withDrawAmount > unUsedAmount) {
                // TODO: User STOP
                // lpUserStop(_lpinfo.sourceChain, challengeInfo.token, challengeInfo.ebc);
                idleAmount(challengeInfo.token);
            }
            bool success = IERC20(challengeInfo.token).transfer(msg.sender, withDrawAmount);
            require(success, "ERC20 Transfer Fail");
            require(address(this).balance >= pledgeAmount, "Insufficient balance");
            payable(msg.sender).transfer(pledgeAmount);
        } else {
            uint256 totalValue = withDrawAmount + pledgeAmount;
            if (totalValue > unUsedAmount) {
                lpUserStop(_lpinfo.sourceChain, challengeInfo.token, challengeInfo.ebc);
            }
            require(address(this).balance >= totalValue, "Insufficient balance");
            payable(msg.sender).transfer(totalValue);
        }
    }

    // makerChllenger MakeGood
    function challengerMakeGood(bytes32 challengeID) external onlyOwner {
        require(challengeInfos[challengeID].challengeState == 1, "MC_ANSWER");
        require(block.timestamp > challengeInfos[challengeID].endTime, "UW_TIME");
        challengeInfos[challengeID].challengeState = 3;

        OperationsLib.challengeInfo storage challengeInfo = challengeInfos[challengeID];
        // address ebcAddress = getManager().getEBC(challengeInfo.ebcid);
        address ebcAddress = challengeInfo.ebc;
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
        challengeInfo.challengeState = 4;
        // uint256 pledgeAmount = challengeInfo.pledged;
        require(challengePleged > challengeInfo.pledged, "challengePleged Insufficient balance");
        challengePleged -= challengeInfo.pledged;
        // Subtract the pledge money transferred by the user challenge from the total pledge money.
        emit LogChallengerCompensation(
            address(getMakerFactory),
            challengeID,
            baseValue,
            challengeInfo.pledged,
            additiveValue
        );
        if (challengeInfo.token != address(0)) {
            require(unUsedAmount >= withDrawAmount, "Insufficient balance");
            bool success = IERC20(challengeInfo.token).transfer(msg.sender, withDrawAmount);
            require(success, "ERC20 Transfer Fail");
            require(address(this).balance >= challengeInfo.pledged, "Insufficient balance");
            payable(msg.sender).transfer(challengeInfo.pledged);
        } else {
            uint256 totalValue = withDrawAmount + challengeInfo.pledged;
            require(unUsedAmount >= totalValue, "Insufficient balance");
            require(address(this).balance >= totalValue, "Insufficient balance");
            payable(msg.sender).transfer(totalValue);
        }
    }

    // maker responds to arbitration request
    function makerChallenger(
        OperationsLib.Transaction memory _userTx,
        OperationsLib.Transaction memory _makerTx,
        bytes32[] memory _makerProof
    ) external onlyOwner {
        // IORManager manager = getManager();
        // Get the corresponding challengeID through txinfo.
        bytes32 challengeID = OperationsLib.getChallengeID(_userTx);
        // The corresponding challengeInfo is required to be in a waiting for maker state.
        require(challengeInfos[challengeID].challengeState == 1, "MC_ANSWER");
        // Change the corresponding challengeInfos state to maker success
        challengeInfos[challengeID].challengeState = 2;
        challengeInfos[challengeID].endTime = block.timestamp;
        // address ebcAddress = manager.getEBC(challengeInfos[challengeID].ebcid);
        address ebcAddress = challengeInfos[challengeID].ebc;
        // Determine whether sourceAddress in txinfo is an MDC address
        require(_makerTx.from == msg.sender, "MC_SENDER");
        // userTx,makerTx and makerProof are provided to EBC and verified to pass
        require(IORProtocal(ebcAddress).checkMakerChallenge(_userTx, _makerTx), "MC_ERROR");
        // Obtaining _makerTx Validity Proof by EBC
        // TODO: get responseSafetyCode
        uint256 responseSafetyCode = 0;
        address tokenAddress = address(0);
        bytes32 makerResponse = keccak256(
            abi.encodePacked(
                uint256(_makerTx.chainId),
                _makerTx.from,
                _makerTx.to,
                _makerTx.value,
                responseSafetyCode,
                tokenAddress
            )
        );
        console.logString("makerResponse responseTxinfo");
        console.logBytes32(makerResponse);
        console.logBytes32(challengeInfos[challengeID].responseTxinfo);
        // The proof of validity of userTx is required to be consistent with that of makerTx.
        require(challengeInfos[challengeID].responseTxinfo == makerResponse, "MCE_UNMATCH");
        // Subtract the pledge money transferred by the user challenge from the total pledge money.
        challengePleged -= challengeInfos[challengeID].pledged;
        emit LogChallengeInfo(address(this), challengeID, challengeInfos[challengeID], _makerTx);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
}
