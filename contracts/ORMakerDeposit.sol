// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./interface/IORMakerDeposit.sol";
import "./library/Operation.sol";
import "./interface/IORManager.sol";
import "./interface/IORProtocal.sol";
import "./interface/IERC20.sol";
import "./interface/IORMakerV1Factory.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract ORMakerDeposit is IORMakerDeposit {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // challenge pleged eth amount
    uint256 public challengePleged;
    address public getMakerFactory;
    // pairId->lpPairInfo
    mapping(bytes32 => OperationsLib.lpPairInfo) public lpInfo;
    // challengeInfos
    mapping(bytes32 => OperationsLib.challengeInfo) private challengeInfos;
    // After the User forcibly stops LP, Maker delays the withdrawal time.
    mapping(address => uint256) public pledgeTokenLPStopDealyTime;
    // pledgeToken=> amount
    EnumerableMap.AddressToUintMap private pledgeBalance;
    // chainID => pledgeToken => amount
    mapping(uint256 => EnumerableMap.AddressToUintMap) private chainPledgeBalance;
    // pledgeToken => pairs
    mapping(address => EnumerableSet.Bytes32Set) private pledgeTokenPairs;
    // chainID => pairs
    mapping(uint256 => EnumerableSet.Bytes32Set) private chainPairs;
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function initialize(address _owner) public {
        require(_owner != address(0), "Owner address error");
        getMakerFactory = msg.sender;
        owner = _owner;
    }

    function getPledgeBalanceByChainToken(uint256 _chainId, address _tokenAddress) external view returns (uint256) {
        (, uint256 value) = chainPledgeBalance[_chainId].tryGet(_tokenAddress);
        return value;
    }

    function pairExist(uint256 chainId, bytes32 pairId) external view returns (bool) {
        return chainPairs[chainId].contains(pairId);
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

    function getManager() private view returns (IORManager manager) {
        manager = IORMakerV1Factory(getMakerFactory).getManager();
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

    function calcLpPledgeAmount(
        OperationsLib.calcLpNeedPledgeAmountParams[] calldata _lpinfos
    )
        external
        view
        returns (
            address pledgedToken,
            OperationsLib.lpPledgeCalculate[] memory pledgeListData,
            uint256 totalPledgeValue
        )
    {
        (pledgedToken, pledgeListData) = getManager().calcLpPledgeAmount(_lpinfos);
        for (uint256 i = 0; i < pledgeListData.length; ) {
            pledgeListData[i].pledged = this.getPledgeBalanceByChainToken(pledgeListData[i].chainId, pledgedToken);
            if (pledgeListData[i].pledgeValue > pledgeListData[i].pledged) {
                totalPledgeValue += pledgeListData[i].pledgeValue - pledgeListData[i].pledged;
            }
            unchecked {
                ++i;
            }
        }
    }

    function lpAction(
        OperationsLib.lpInfo[] calldata _lpinfos,
        bytes32[][] calldata pairProof
    ) external payable onlyOwner {
        require(_lpinfos.length > 0, "Inconsistent Array Length");
        require(_lpinfos.length == pairProof.length, "Inconsistent Array Length");
        IORManager manager = getManager();
        OperationsLib.tokenInfo memory depositToken = manager.getTokenInfo(
            _lpinfos[0].sourceChain,
            _lpinfos[0].sourceTAddress
        );
        // address pledgedToken = depositToken.mainTokenAddress;

        OperationsLib.calcLpNeedPledgeAmountParams[]
            memory calcLpNeedPledgeAmountParams = new OperationsLib.calcLpNeedPledgeAmountParams[](_lpinfos.length);
        for (uint256 i = 0; i < _lpinfos.length; ) {
            calcLpNeedPledgeAmountParams[i] = OperationsLib.calcLpNeedPledgeAmountParams(
                "",
                _lpinfos[i].sourceTAddress,
                _lpinfos[i].sourceChain,
                _lpinfos[i].ebcid,
                _lpinfos[i].maxPrice
            );
            unchecked {
                ++i;
            }
        }
        (address pledgedToken, OperationsLib.lpPledgeCalculate[] memory pledgeListData, uint256 totalPledgeValue) = this
            .calcLpPledgeAmount(calcLpNeedPledgeAmountParams);
        for (uint256 i = 0; i < _lpinfos.length; ) {
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            require(_lpinfo.minPrice <= _lpinfo.maxPrice, "Illegal minPrice maxPrice value");
            bytes32 pairId = OperationsLib.getPairID(_lpinfo);
            require(manager.isSupportChain(_lpinfo.sourceChain, _lpinfo.sourceTAddress), "Chain Not Supported");
            require(manager.isSupportPair(pairId, pairProof[i]), "Pair Not Supported");
            require(!this.pairExist(_lpinfo.sourceChain, pairId), "Pair already exists");
            // first init lpPair
            require(lpInfo[pairId].startTime == 0 && lpInfo[pairId].stopTime == 0, "LPACTION_LPID_UNSTOP");
            uint256 sourceChain = _lpinfo.sourceChain;
            depositToken = manager.getTokenInfo(_lpinfo.sourceChain, _lpinfo.sourceTAddress);
            require(depositToken.mainTokenAddress == pledgedToken, "LP that does not support multiple pledge tokens");
            address ebcAddress = IORManager(manager).getEBC(_lpinfo.ebcid);
            require(ebcAddress != address(0), "LPACTION_EBCADDRESS_0");
            // chain add pair
            bool created = chainPairs[sourceChain].add(pairId);
            require(created, "chainPairs Pair Exist");
            created = pledgeTokenPairs[pledgedToken].add(pairId);
            require(created, "pledgeTokenPairs Pair Exist");
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
            unchecked {
                ++i;
            }
        }
        // valid
        if (totalPledgeValue > 0) {
            (, uint256 pledgedValue) = pledgeBalance.tryGet(pledgedToken);
            for (uint256 i = 0; i < pledgeListData.length; ) {
                // save 1
                uint256 addPledgedValue = (pledgeListData[i].pledgeValue - pledgeListData[i].pledged);
                pledgedValue += addPledgedValue;
                // save 2
                uint256 chainId = pledgeListData[i].chainId;
                EnumerableMap.AddressToUintMap storage chainPledgeTokenBalance = chainPledgeBalance[chainId];
                (, uint256 tokenValue) = chainPledgeTokenBalance.tryGet(pledgedToken);
                chainPledgeTokenBalance.set(pledgedToken, tokenValue + addPledgedValue);
                unchecked {
                    ++i;
                }
            }
            pledgeBalance.set(pledgedToken, pledgedValue);

            if (pledgedToken == address(0)) {
                //  int256 AssessmentAmount = int256(supplement) - int256(unUsedAmount - msg.value);
                require(msg.value >= totalPledgeValue, "Insufficient pledge quantity");
            } else {
                if (totalPledgeValue > 0) {
                    uint256 allowance = IERC20(pledgedToken).allowance(msg.sender, address(this));
                    require(allowance >= totalPledgeValue, "Token Insufficient pledge quantity");
                    bool success = IERC20(pledgedToken).transferFrom(msg.sender, address(this), totalPledgeValue);
                    require(success, "TransferFrom Fail");
                }
            }
        }
    }

    // LPPause
    function lpPause(OperationsLib.lpInfo[] calldata _lpinfos) external onlyOwner {
        IORManager manager = getManager();
        for (uint256 i = 0; i < _lpinfos.length; ) {
            // calc root Hash
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            bytes32 pairId = OperationsLib.getPairID(_lpinfo);
            require(lpInfo[pairId].lpId != "", "LPPAUSE_LPID_UNUSED");
            require(this.pairExist(_lpinfo.sourceChain, pairId), "Pair does not exist");
            require(lpInfo[pairId].startTime != 0 && lpInfo[pairId].stopTime == 0, "LPPAUSE_LPID_UNACTION");
            address ebcAddress = manager.getEBC(_lpinfo.ebcid);
            require(ebcAddress != address(0), "LPPAUSE_EBCADDRESS_0");
            // uint256 stopDelayTime = getChainInfoByChainID(_lpinfo.sourceChain).stopDelayTime;
            (, , , , uint256 stopDelayTime, ) = getManager().getChain(_lpinfo.sourceChain);
            lpInfo[pairId].stopTime = block.timestamp + stopDelayTime;
            lpInfo[pairId].startTime = 0;
            emit LogLPPause(pairId, lpInfo[pairId].lpId, _lpinfo);
            unchecked {
                ++i;
            }
        }
    }

    function lpRestart(OperationsLib.lpRestart[] calldata _lps) external onlyOwner {
        for (uint256 i = 0; i < _lps.length; ) {
            OperationsLib.lpRestart memory _item = _lps[i];
            bytes32 pairId = _item.pid;
            bytes32 lpId = _item.lpid;
            require(lpInfo[pairId].lpId != "", "LPPAUSE_LPID_UNUSED");
            require(lpInfo[pairId].lpId == lpId, "LPPAUSE_LPID_ERROR");
            require(lpInfo[pairId].startTime == 0 && lpInfo[pairId].stopTime != 0, "LPUPDATE_NOTPAUSED");
            lpInfo[pairId].startTime = block.timestamp;
            lpInfo[pairId].stopTime = 0;
            emit LogLPRestart(pairId, lpId, _item.gasFee, _item.tradingFee);
            unchecked {
                ++i;
            }
        }
    }

    // LPStop
    function lpStop(OperationsLib.lpInfo[] calldata _lpinfos) external onlyOwner {
        IORManager manager = getManager();
        for (uint256 i = 0; i < _lpinfos.length; ) {
            OperationsLib.lpInfo memory _lpinfo = _lpinfos[i];
            bytes32 pairId = OperationsLib.getPairID(_lpinfo);
            require(lpInfo[pairId].lpId != "", "LPPAUSE_LPID_UNUSED");
            require(lpInfo[pairId].startTime == 0 && lpInfo[pairId].stopTime != 0, "LPSTOP_LPID_UNPAUSE");
            require(block.timestamp > lpInfo[pairId].stopTime, "LPSTOP_LPID_TIMEUNABLE");
            OperationsLib.tokenInfo memory depositToken = manager.getTokenInfo(
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
                for (uint256 j = 0; j < chainPledgeTokenBalance.length(); ) {
                    (address token, uint256 chainTokenValue) = chainPledgeTokenBalance.at(j);
                    bool removed = chainPledgeTokenBalance.remove(token);
                    require(removed, "chainPledgeTokenBalance remove not exist");
                    (, uint256 value) = pledgeBalance.tryGet(pledgedToken);
                    require(value >= chainTokenValue, "chainPledgeTokenBalance gt pledgeBalance");
                    //
                    bool created = pledgeBalance.set(pledgedToken, value - chainTokenValue);
                    require(!created, "PledgeBalance Not Exist");
                    unchecked {
                        ++j;
                    }
                }
            }
            emit LogLPStop(pairId, lpInfo[pairId].lpId, _lpinfo);
            unchecked {
                ++i;
            }
        }
    }

    // LPUpdate
    function lpUpdate(OperationsLib.lpRestart[] calldata _lpinfos) external onlyOwner {
        for (uint256 i = 0; i < _lpinfos.length; ) {
            OperationsLib.lpRestart memory _changeRow = _lpinfos[i];
            bytes32 pairId = _changeRow.pid;
            bytes32 lpId = _changeRow.lpid;
            require(lpInfo[pairId].lpId != "", "LPPAUSE_LPID_UNUSED");
            require(lpInfo[pairId].lpId == lpId, "LPPAUSE_LPID_ERROR");
            require(lpInfo[pairId].startTime == 0 && lpInfo[pairId].stopTime != 0, "LPUPDATE_NOTPAUSED");
            emit LogLPUpdate(pairId, lpId, _changeRow.gasFee, _changeRow.tradingFee);
            unchecked {
                ++i;
            }
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
            bool success = IERC20(tokenAddress).transfer(msg.sender, amount);
            require(success, "TransferFrom Fail");
        } else {
            payable(msg.sender).transfer(amount);
            // require(success, "TransferFrom Fail");
        }
    }

    // userChallenge
    // User Initiates Arbitration Request
    function userChallenge(OperationsLib.txInfo memory _txinfo, bytes32[] memory _txproof) external payable {
        address ebcAddress = getManager().getEBC(_txinfo.ebcid);
        // Determine whether sourceAddress in txinfo is consistent with the caller's address
        require(_txinfo.sourceAddress == msg.sender, "UCE_SENDER");
        // Determine whether destAddress in txinfo is an MDC address
        require(_txinfo.destAddress == owner, "UCE_4");
        // Verify whether it is within the period of appeal
        (, , , uint256 maxReceiptTime, , ) = getManager().getChain(_txinfo.chainID);

        require(block.timestamp > _txinfo.timestamp + maxReceiptTime, "UCE_5");

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
        (, , uint256 maxDisputeTime, , , ) = getManager().getChain(_txinfo.chainID);
        challengeInfos[challengeID].stopTime = block.timestamp + maxDisputeTime;
        challengeInfos[challengeID].endTime = block.timestamp + maxDisputeTime + maxDisputeTime;

        // The pledge transferred by the user is included in the total pledge.
        challengePleged += msg.value;
        emit LogChallengeInfo(getMakerFactory, challengeID, challengeInfos[challengeID], _txinfo);
    }

    // LPStop
    function lpUserStop(uint256 sourceChain, address sourceToken, uint256 ebcid) internal {
        IORManager manager = getManager();
        OperationsLib.tokenInfo memory tokenInfo = manager.getTokenInfo(sourceChain, sourceToken);
        address ebcAddress = manager.getEBC(ebcid);
        require(ebcAddress != address(0), "USER_LPStop_EBCADDRESS_0");
        address pledgedToken = tokenInfo.mainTokenAddress;
        (, , , , uint256 stopDelayTime, ) = getManager().getChain(sourceChain);
        // is exists
        if (chainPairs[sourceChain].length() > 0) {
            bytes32[] memory pairs = this.getPairsByChain(sourceChain);
            for (uint256 i = 0; i < pairs.length; ) {
                bytes32 pairId = pairs[i];
                require(this.pairExist(sourceChain, pairId), "Pair does not exist");
                bool success = chainPairs[sourceChain].remove(pairId);
                require(success, "Remove chainPairs Fail");
                success = pledgeTokenPairs[pledgedToken].remove(pairId);
                require(success, "Remove chainPairs Fail");
                lpInfo[pairs[i]].startTime = 0;
                lpInfo[pairs[i]].stopTime = 0;
                // }
                emit LogLPUserStop(pairs[i], lpInfo[pairs[i]].lpId);
                unchecked {
                    ++i;
                }
            }
            EnumerableMap.AddressToUintMap storage chainPledgeTokenBalance = chainPledgeBalance[sourceChain];
            (, uint256 pledgedTokenValue) = chainPledgeTokenBalance.tryGet(pledgedToken);
            // Release all deposits
            bool removed = chainPledgeBalance[sourceChain].remove(pledgedToken);
            require(removed, "Remove chainPledgeBalance Fail");
            (, uint256 pledgedValue) = pledgeBalance.tryGet(pledgedToken);
            bool created = pledgeBalance.set(pledgedToken, pledgedValue - pledgedTokenValue);
            require(!created, "PledgeBalance Not Exist");
        }
        //     //Set Maker withdrawal time to the current time plus stopDelayTime.
        pledgeTokenLPStopDealyTime[pledgedToken] = block.timestamp + stopDelayTime;
    }

    // userWithDraw
    function userWithDraw(OperationsLib.txInfo memory _userTx, OperationsLib.lpInfo memory _lpinfo) external {
        bytes32 challengeID = OperationsLib.getChallengeID(_userTx);
        IORManager manager = getManager();
        // When the state of challengeInfos is 'waiting for maker' and the stopTime of challengeInfos has passed, the user can withdraw money.
        require(_userTx.sourceAddress == msg.sender, "UW_SENDER");
        OperationsLib.challengeInfo storage challengeInfo = challengeInfos[challengeID];
        require(challengeInfo.challengeState == 1, "UW_WITHDRAW");
        require(block.timestamp > challengeInfo.stopTime, "UW_TIME");
        bytes32 pairId = OperationsLib.getPairID(_lpinfo);
        require(this.pairExist(_lpinfo.sourceChain, pairId), "Pair does not exist");
        address ebcAddress = manager.getEBC(challengeInfo.ebcid);
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
        emit LogChallengerCompensation(getMakerFactory, challengeID, baseValue, challengeInfo.pledged, additiveValue);
        // Subtract the pledge money transferred by the user challenge from the total pledge money.
        if (challengeInfo.token != address(0)) {
            if (withDrawAmount > unUsedAmount) {
                lpUserStop(_lpinfo.sourceChain, challengeInfo.token, challengeInfo.ebcid);
                idleAmount(challengeInfo.token);
            }
            bool success = IERC20(challengeInfo.token).transfer(msg.sender, withDrawAmount);
            require(success, "ERC20 Transfer Fail");
            require(address(this).balance >= pledgeAmount, "Insufficient balance");
            payable(msg.sender).transfer(pledgeAmount);
        } else {
            uint256 totalValue = withDrawAmount + pledgeAmount;
            if (totalValue > unUsedAmount) {
                lpUserStop(_lpinfo.sourceChain, challengeInfo.token, challengeInfo.ebcid);
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
        address ebcAddress = getManager().getEBC(challengeInfo.ebcid);
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
        emit LogChallengerCompensation(getMakerFactory, challengeID, baseValue, challengeInfo.pledged, additiveValue);
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
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
        bytes32[] memory _makerProof
    ) external onlyOwner {
        IORManager manager = getManager();
        // Get the corresponding challengeID through txinfo.
        bytes32 challengeID = OperationsLib.getChallengeID(_userTx);
        // The corresponding challengeInfo is required to be in a waiting for maker state.
        require(challengeInfos[challengeID].challengeState == 1, "MC_ANSWER");
        // Change the corresponding challengeInfos state to maker success
        challengeInfos[challengeID].challengeState = 2;
        challengeInfos[challengeID].endTime = block.timestamp;
        address ebcAddress = manager.getEBC(challengeInfos[challengeID].ebcid);
        // Determine whether sourceAddress in txinfo is an MDC address
        require(_makerTx.sourceAddress == msg.sender, "MC_SENDER");
        // userTx,makerTx and makerProof are provided to EBC and verified to pass
        require(IORProtocal(ebcAddress).checkMakerChallenge(_userTx, _makerTx, _makerProof), "MC_ERROR");
        // Obtaining _makerTx Validity Proof by EBC
        bytes32 makerResponse = keccak256(
            abi.encodePacked(
                _makerTx.lpid,
                uint256(_makerTx.chainID),
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

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
}
