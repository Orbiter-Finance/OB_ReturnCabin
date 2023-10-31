// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORMakerDeposit} from "./interface/IORMakerDeposit.sol";
import {IORManager} from "./interface/IORManager.sol";
import {IORMDCFactory} from "./interface/IORMDCFactory.sol";
import {IORChallengeSpv} from "./interface/IORChallengeSpv.sol";
import {IOREventBinding} from "./interface/IOREventBinding.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {HelperLib} from "./library/HelperLib.sol";
import {RuleLib} from "./library/RuleLib.sol";
import {ConstantsLib} from "./library/ConstantsLib.sol";
import {BridgeLib} from "./library/BridgeLib.sol";
import {VersionAndEnableTime} from "./VersionAndEnableTime.sol";

contract ORMakerDeposit is IORMakerDeposit, VersionAndEnableTime {
    using HelperLib for uint[];
    using HelperLib for address[];
    using HelperLib for bytes;
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    uint internal constant MIN_CHALLENGE_DEPOSIT_AMOUNT = 0.005 ether;

    // VersionAndEnableTime._version and _enableTime use a slot

    // Warning: the following order and type changes will cause state verification changes
    address private _owner;
    IORMDCFactory private _mdcFactory;
    bytes32 private _columnArrayHash;
    mapping(uint64 => address) private _spvs; // chainId => spvAddress
    bytes32 private _responseMakersHash; // hash(response maker list), not just owner, to improve tps
    mapping(address => RuleLib.RootWithVersion) private _rulesRoots; // ebc => merkleRoot(rules), version
    mapping(bytes32 => uint) private _pledgeBalances; // hash(ebc, sourceChainId, sourceToken) => pledgeBalance
    mapping(address => uint) private _freezeAssets; // token(ETH: 0) => freezeAmount
    mapping(bytes32 => ChallengeInfo) private _challenges; // hash(sourceChainId, transactionHash) => ChallengeInfo
    mapping(address => WithdrawRequestInfo) private _withdrawRequestInfo;
    mapping(uint256 => ChallengeNode) private _challengeNodeList;
    uint256 private _challengeNodeHead;
    uint256 private _challengeDeposit;

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    modifier onlyNoRequestTimestamp(address requestToken) {
        require(_withdrawRequestInfo[requestToken].requestTimestamp == 0, "RHB");
        _;
    }

    modifier onlyRequestTimestampCheckPass(address requestToken) {
        require(
            _withdrawRequestInfo[requestToken].requestTimestamp > 0 &&
                block.timestamp >= _withdrawRequestInfo[requestToken].requestTimestamp,
            "WTN"
        );
        _;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    function initialize(address owner_) external {
        require(_owner == address(0), "_ONZ");
        require(owner_ != address(0), "OZ");

        _owner = owner_;
        _mdcFactory = IORMDCFactory(msg.sender);
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function mdcFactory() external view returns (address) {
        return address(_mdcFactory);
    }

    function columnArrayHash() external view returns (bytes32) {
        return _columnArrayHash;
    }

    function updateColumnArray(
        uint64 enableTime,
        address[] calldata dealers,
        address[] calldata ebcs,
        uint64[] calldata chainIds
    ) external onlyOwner {
        versionIncreaseAndEnableTime(enableTime);

        require(dealers.length < 10 && ebcs.length < 10 && chainIds.length < 100, "DECOF");

        IORManager manager = IORManager(_mdcFactory.manager());
        for (uint i = 0; i < ebcs.length; ) {
            require(manager.ebcIncludes(ebcs[i]), "EI"); // Has invalid ebc

            unchecked {
                i++;
            }
        }

        for (uint i = 0; i < chainIds.length; ) {
            BridgeLib.ChainInfo memory chainInfo = manager.getChainInfo(chainIds[i]);
            require(chainInfo.id > 0, "CI"); // Invalid chainId

            unchecked {
                i++;
            }
        }

        _columnArrayHash = abi.encode(dealers, ebcs, chainIds).hash();
        emit ColumnArrayUpdated(_mdcFactory.implementation(), _columnArrayHash, dealers, ebcs, chainIds);
    }

    function spv(uint64 chainId) external view returns (address) {
        return _spvs[chainId];
    }

    function updateSpvs(uint64 enableTime, address[] calldata spvs, uint64[] calldata chainIds) external onlyOwner {
        versionIncreaseAndEnableTime(enableTime);

        IORManager manager = IORManager(_mdcFactory.manager());
        address impl = _mdcFactory.implementation();

        for (uint i = 0; i < chainIds.length; i++) {
            BridgeLib.ChainInfo memory chainInfo = manager.getChainInfo(chainIds[i]);
            require(chainInfo.id > 0, "CI"); // Invalid chainId
            require(chainInfo.spvs.includes(spvs[i]), "SI"); // Invalid spv

            _spvs[chainIds[i]] = spvs[i];

            emit SpvUpdated(impl, chainIds[i], spvs[i]);
        }
    }

    function responseMakersHash() external view returns (bytes32) {
        return _responseMakersHash;
    }

    function updateResponseMakers(uint64 enableTime, bytes[] calldata responseMakerSignatures) external onlyOwner {
        versionIncreaseAndEnableTime(enableTime);

        bytes32 data = abi.encode(address(this)).hash();

        uint[] memory responseMakers_ = new uint[](responseMakerSignatures.length);
        for (uint i = 0; i < responseMakerSignatures.length; i++) {
            responseMakers_[i] = uint(uint160(data.toEthSignedMessageHash().recover(responseMakerSignatures[i])));
        }

        _responseMakersHash = abi.encode(responseMakers_).hash();
        emit ResponseMakersUpdated(_mdcFactory.implementation(), responseMakers_);
    }

    function freezeAssets(address token) external view returns (uint) {
        return _freezeAssets[token];
    }

    function deposit(address token, uint amount) external payable {
        // TODO: This method is useless if it does not need to throw an event
        // ETH received by default
        // ERC20 calls safeTransferFrom, can also call `transfer` send assets to address(this)
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function getWithdrawRequestInfo(address targetToken) external view returns (WithdrawRequestInfo memory) {
        return _withdrawRequestInfo[targetToken];
    }

    function withdrawRequest(
        address requestToken,
        uint requestAmount
    ) external onlyOwner onlyNoRequestTimestamp(requestToken) {
        uint64 requestTimestamp = uint64(
            block.timestamp + IORManager(_mdcFactory.manager()).getChallengeWithdrawDelay()
        );
        _withdrawRequestInfo[requestToken] = WithdrawRequestInfo(requestAmount, requestTimestamp, requestToken);
        emit WithdrawRequested(requestAmount, requestTimestamp, requestToken);
    }

    function withdraw(address token) external onlyOwner onlyRequestTimestampCheckPass(token) {
        WithdrawRequestInfo storage requestInfo = _withdrawRequestInfo[token];
        requestInfo.requestTimestamp = 0;

        uint256 balance;
        if (token == address(0)) {
            balance = address(this).balance - _freezeAssets[requestInfo.requestToken] - _challengeDeposit;

            require(balance >= requestInfo.requestAmount, "ETH: IF");

            (bool sent, ) = payable(msg.sender).call{value: requestInfo.requestAmount}("");

            require(sent, "ETH: SE");
        } else {
            balance =
                IERC20(requestInfo.requestToken).balanceOf(address(this)) -
                _freezeAssets[requestInfo.requestToken];

            require(balance >= requestInfo.requestAmount, "ERC20: IF");

            IERC20(requestInfo.requestToken).safeTransfer(msg.sender, requestInfo.requestAmount);
        }
    }

    function rulesRoot(address ebc) external view returns (RuleLib.RootWithVersion memory) {
        return _rulesRoots[ebc];
    }

    function updateRulesRoot(
        uint64 enableTime,
        address ebc,
        RuleLib.Rule[] calldata rules,
        RuleLib.RootWithVersion calldata rootWithVersion,
        uint64[] calldata sourceChainIds,
        uint[] calldata pledgeAmounts
    ) external payable onlyOwner {
        versionIncreaseAndEnableTime(enableTime);

        _updateRulesRoot(ebc, rules, rootWithVersion);

        require(sourceChainIds.length == pledgeAmounts.length, "SPL");

        uint increaseAmount;
        for (uint i = 0; i < sourceChainIds.length; ) {
            // TODO: Must save pledge amount by sourceChainId?
            //       Is it feasible to only by token?
            bytes32 k = abi.encode(ebc, sourceChainIds[i], address(0)).hash();

            if (pledgeAmounts[i] > _pledgeBalances[k]) {
                uint _d = pledgeAmounts[i] - _pledgeBalances[k];
                increaseAmount += _d;
            }

            _pledgeBalances[k] = pledgeAmounts[i];

            unchecked {
                i++;
            }
        }

        require(increaseAmount <= msg.value, "IV"); // Insufficient value
    }

    function updateRulesRootERC20(
        uint64 enableTime,
        address ebc,
        RuleLib.Rule[] calldata rules,
        RuleLib.RootWithVersion calldata rootWithVersion,
        uint64[] calldata sourceChainIds,
        uint[] calldata pledgeAmounts,
        address token
    ) external onlyOwner {
        versionIncreaseAndEnableTime(enableTime);

        _updateRulesRoot(ebc, rules, rootWithVersion);

        require(sourceChainIds.length == pledgeAmounts.length, "SPL");

        for (uint i = 0; i < sourceChainIds.length; ) {
            bytes32 k = abi.encode(ebc, sourceChainIds[i], token).hash();

            if (pledgeAmounts[i] > _pledgeBalances[k]) {
                IERC20(token).safeTransferFrom(msg.sender, address(this), pledgeAmounts[i] - _pledgeBalances[k]);
            }

            unchecked {
                i++;
            }
        }
    }

    function _updateRulesRoot(
        address ebc,
        RuleLib.Rule[] calldata rules,
        RuleLib.RootWithVersion calldata rootWithVersion
    ) private {
        for (uint i = 0; i < rules.length; ) {
            RuleLib.checkChainIds(rules[i].chainId0, rules[i].chainId1);
            RuleLib.checkWithholdingFees(rules[i].withholdingFee0, rules[i].withholdingFee1);

            unchecked {
                i++;
            }
        }

        IORManager manager = IORManager(_mdcFactory.manager());
        require(manager.ebcIncludes(ebc), "EI"); // Invalid ebc

        require(rootWithVersion.root != bytes32(0), "RZ");
        unchecked {
            require(_rulesRoots[ebc].version + 1 == rootWithVersion.version, "VE");
        }

        _rulesRoots[ebc] = rootWithVersion;

        emit RulesRootUpdated(_mdcFactory.implementation(), ebc, rootWithVersion);
    }

    function _addChallengeNode(uint256 lastChallengeIdentNum, uint256 challengeIdentNum) private {
        ChallengeNode storage challengeNode = _challengeNodeList[challengeIdentNum];
        uint64 currentTime = uint64(block.timestamp);

        if (_challengeNodeHead == 0) {
            _challengeNodeHead = challengeIdentNum;
            challengeNode.challengeCreateTime = currentTime;
        } else {
            if (lastChallengeIdentNum == 0) {
                challengeNode.prev = _challengeNodeHead;
                challengeNode.challengeCreateTime = currentTime;
                _challengeNodeHead = challengeIdentNum;
            } else {
                ChallengeNode storage lastChallengeNode = _challengeNodeList[lastChallengeIdentNum];
                require(
                    lastChallengeNode.challengeCreateTime > 0 &&
                        lastChallengeIdentNum > challengeIdentNum &&
                        challengeIdentNum > lastChallengeNode.prev,
                    "VLNP"
                );

                challengeNode.prev = lastChallengeNode.prev;
                challengeNode.challengeCreateTime = currentTime;
                lastChallengeNode.prev = challengeIdentNum;
            }
        }
    }

    function getCanChallengeContinue(uint256 challengeIdentNum) external view returns (bool) {
        return _getCanChallengeContinue(challengeIdentNum);
    }

    function _getCanChallengeContinue(uint256 challengeIdentNum) private view returns (bool) {
        ChallengeNode memory currChallengeNode = _challengeNodeList[challengeIdentNum];
        require(currChallengeNode.challengeCreateTime > 0, "UCY");

        bool makerNotResponded = currChallengeNode.makerFailedTime == 0 && currChallengeNode.makerSuccessTime == 0;
        if (currChallengeNode.prev == 0) {
            return makerNotResponded;
        } else {
            bool prevMakerResponded = _challengeNodeList[currChallengeNode.prev].makerFailedTime > 0 ||
                _challengeNodeList[currChallengeNode.prev].makerSuccessTime > 0;
            return makerNotResponded && prevMakerResponded;
        }
    }

    function challenge(
        uint64 sourceTxTime,
        uint64 sourceChainId,
        uint64 sourceTxBlockNum,
        uint64 sourceTxIndex,
        bytes32 sourceTxHash,
        address freezeToken,
        uint freezeAmount1,
        uint256 lastChallengeIdentNum
    ) external payable {
        uint256 startGasNum = gasleft();
        bytes32 challengeId = abi.encode(sourceChainId, sourceTxHash).hash();
        // Submit challenge before the winner is decided
        require(_challenges[challengeId].result.winner == address(0), "CE");
        // Make sure the source timestamp is before the challenge
        require(uint64(block.timestamp) >= sourceTxTime, "STOF");

        require(_challenges[challengeId].statement[msg.sender].challengeTime == 0, "CT");

        if (freezeToken == address(0)) {
            require(msg.value == (freezeAmount1 + MIN_CHALLENGE_DEPOSIT_AMOUNT), "IF+MD");
        } else {
            require(msg.value == MIN_CHALLENGE_DEPOSIT_AMOUNT, "IF");
            IERC20(freezeToken).safeTransferFrom(msg.sender, address(this), freezeAmount1);
        }
        _challengeDeposit += MIN_CHALLENGE_DEPOSIT_AMOUNT;

        uint256 challengeIdentNum = HelperLib.uint64ConcatToDecimal(
            sourceTxTime,
            sourceChainId,
            sourceTxBlockNum,
            sourceTxIndex
        );

        if (_challengeNodeHead != 0 && _challengeNodeHead > challengeIdentNum) {
            require(lastChallengeIdentNum > 0, "LCINE");
        }

        // TODO: For more challenger challenge the same tx, the same challenge will pass
        if (_challengeNodeList[challengeIdentNum].challengeCreateTime == 0) {
            _addChallengeNode(lastChallengeIdentNum, challengeIdentNum);
        }

        // TODO: Currently it is assumed that the pledged assets of the challenger and the owner are the same
        uint freezeAmount0 = freezeAmount1;

        // Freeze mdc's owner assets and the assets in of challenger
        _freezeAssets[freezeToken] += freezeAmount0 + freezeAmount1;

        _challenges[challengeId].statement[msg.sender] = ChallengeStatement({
            sourceTxFrom: 0,
            sourceTxTime: sourceTxTime,
            freezeToken: freezeToken,
            challengeUserRatio: 0,
            freezeAmount0: freezeAmount0,
            freezeAmount1: freezeAmount1,
            challengeTime: uint64(block.timestamp),
            abortTime: 0,
            sourceTxBlockNum: sourceTxBlockNum,
            sourceTxIndex: sourceTxIndex,
            challengerVerifyTransactionFee: (uint128(startGasNum) - uint128(gasleft())) *
                (uint128(block.basefee) + uint128(IORManager(_mdcFactory.manager()).getPriorityFee()))
        });

        emit ChallengeInfoUpdated({
            challengeId: challengeId,
            statement: _challenges[challengeId].statement[msg.sender],
            result: _challenges[challengeId].result
        });
    }

    function checkChallenge(
        uint64 sourceChainId,
        bytes32 sourceTxHash,
        uint[] calldata verifiedData0,
        address[] calldata challenger
    ) external {
        bytes32 challengeId = abi.encode(uint64(sourceChainId), sourceTxHash).hash();
        ChallengeInfo storage challengeInfo = _challenges[challengeId];
        ChallengeStatement memory winnerStatement = challengeInfo.statement[challengeInfo.result.winner];
        ChallengeResult memory result = challengeInfo.result;
        address freezeToken;
        uint256 unFreezeAmount;

        for (uint i = 0; i < challenger.length; i++) {
            ChallengeStatement storage challengeStatement = challengeInfo.statement[challenger[i]];

            // Make sure the challenge exists
            require(challengeStatement.challengeTime > 0, "CNE");

            require(
                _getCanChallengeContinue(
                    HelperLib.uint64ConcatToDecimal(
                        challengeStatement.sourceTxTime,
                        sourceChainId,
                        challengeStatement.sourceTxBlockNum,
                        challengeStatement.sourceTxIndex
                    )
                ),
                "NCCF"
            );

            require(challengeStatement.abortTime == 0, "CA");

            // Make sure verifyChallengeDest is not done yet
            require(result.verifiedTime1 == 0, "VT1NZ");

            IORManager manager = IORManager(_mdcFactory.manager());

            if (result.verifiedTime0 == 0) {
                /****** challenger fai ******/
                BridgeLib.ChainInfo memory chainInfo = manager.getChainInfo(sourceChainId);

                require(
                    block.timestamp > chainInfo.maxVerifyChallengeSourceTxSecond + challengeStatement.sourceTxTime,
                    "VCST"
                );

                unFreezeAmount += _challengerFailed(challengeStatement, sourceChainId);
                freezeToken = challengeStatement.freezeToken;
            } else {
                /****** maker fai ******/
                // Ensure the correctness of verifiedData0
                require(abi.encode(verifiedData0).hash() == result.verifiedDataHash0, "VDH");
                require(result.verifiedTime1 > uint64(block.timestamp), "VDD");

                BridgeLib.ChainInfo memory chainInfo = manager.getChainInfo(uint64(verifiedData0[0]));
                require(
                    block.timestamp > chainInfo.maxVerifyChallengeDestTxSecond + challengeStatement.sourceTxTime,
                    "VCDT"
                );

                unFreezeAmount += _makerFailed(
                    challengeStatement,
                    winnerStatement,
                    result,
                    challenger[i],
                    sourceChainId
                );
                freezeToken = challengeStatement.freezeToken;
            }
            challengeStatement.abortTime = uint64(block.timestamp);

            emit ChallengeInfoUpdated({
                challengeId: challengeId,
                statement: challengeStatement,
                result: challengeInfo.result
            });
        }
        _unFreezeToken(freezeToken, unFreezeAmount);
        _challengeDeposit -= challenger.length * MIN_CHALLENGE_DEPOSIT_AMOUNT;
    }

    /**
     *
     * @param spvAddress The spv's address
     * @param proof The zk's proof
     * @param spvBlockHashs If the blocks of the state proof and tx proof are not in the same segment, need to verify the two blocks
     * @param verifyInfo The public inputs preimage for zk proofs
     *        verifyInfo.data: [chainId, txHash, from, to, token, amount, nonce, timestamp, ruleHash, dest, destToken]
     *        verifyInfo.slots: [...see code]
     * @param rawDatas The raw data list in preimage. [dealers, ebcs, chainIds, ebc, rule]
     */
    function verifyChallengeSource(
        address spvAddress,
        address challenger,
        bytes calldata proof,
        bytes32[2] calldata spvBlockHashs,
        IORChallengeSpv.VerifyInfo calldata verifyInfo,
        bytes calldata rawDatas
    ) external {
        uint256 startGasNum = gasleft();
        BridgeLib.ChainInfo memory chainInfo = IORManager(_mdcFactory.manager()).getChainInfo(
            uint64(verifyInfo.data[0])
        );
        require(chainInfo.spvs.includes(spvAddress), "SI"); // Invalid spv
        require(IORChallengeSpv(spvAddress).verifyChallenge(proof, spvBlockHashs, abi.encode(verifyInfo).hash()), "VF");

        // Check chainId, hash, timestamp
        bytes32 challengeId = abi.encode(uint64(verifyInfo.data[0]), verifyInfo.data[1]).hash();
        require(_challenges[challengeId].statement[challenger].challengeTime > 0, "CTZ");
        require(_challenges[challengeId].result.verifiedTime0 == 0, "VT0NZ");
        require(uint64(verifyInfo.data[7]) == _challenges[challengeId].statement[challenger].sourceTxTime, "ST");

        // Check to address equal owner
        // TODO: Not compatible with starknet network
        require(uint160(verifyInfo.data[2]) == uint160(_owner), "TNEO");

        // Parse rawDatas
        (
            address[] memory dealers,
            address[] memory ebcs,
            uint64[] memory chainIds,
            address ebc,
            RuleLib.Rule memory rule
        ) = abi.decode(rawDatas, (address[], address[], uint64[], address, RuleLib.Rule));

        // Check manager's chainInfo.minVerifyChallengeSourceTxSecond,maxVerifyChallengeSourceTxSecond
        // Get minVerifyChallengeDestTxSecond, maxVerifyChallengeDestTxSecond
        {
            require(verifyInfo.slots[0].account == _mdcFactory.manager(), "VCSTA");
            uint slotK = uint(abi.encode(verifyInfo.data[0], 2).hash()); // abi.encode no need to convert type
            require(uint(verifyInfo.slots[0].key) == slotK + 1, "VCSTK");

            uint timeDiff = block.timestamp - verifyInfo.data[7];
            require(timeDiff >= uint64(verifyInfo.slots[0].value), "MINTOF");
            require(timeDiff <= uint64(verifyInfo.slots[0].value >> 64), "MAXTOF");
        }

        // Check freezeToken, freezeAmount
        {
            // FreezeToken
            require(verifyInfo.slots[1].account == _mdcFactory.manager(), "FTA");
            uint slotK = uint(abi.encode(abi.encode(uint64(verifyInfo.data[0]), verifyInfo.data[4]).hash(), 3).hash());
            require(uint(verifyInfo.slots[1].key) == slotK + 1, "FTK");
            require(
                _challenges[challengeId].statement[challenger].freezeToken ==
                    address(uint160(verifyInfo.slots[1].value)),
                "FTV"
            );

            // FreezeAmount
            require(verifyInfo.slots[2].account == _mdcFactory.manager(), "FAA");
            require(uint(verifyInfo.slots[2].key) == 6, "FAK");
            uint64 _minChallengeRatio = uint64(verifyInfo.slots[2].value);
            require(
                _challenges[challengeId].statement[challenger].freezeAmount1 >=
                    (verifyInfo.data[5] * _minChallengeRatio) / ConstantsLib.RATIO_MULTIPLE,
                "FALV"
            );
        }

        // Check _columnArrayHash
        {
            bytes32 cah = abi.encode(dealers, ebcs, chainIds).hash();
            require(verifyInfo.slots[3].account == address(this), "CAHA");
            require(uint(verifyInfo.slots[3].key) == 3, "CAHK");
            require(bytes32(verifyInfo.slots[3].value) == cah, "CAHV");
        }

        // Check ebc address, destChainId
        uint destChainId;
        {
            IOREventBinding.AmountParams memory ap = IOREventBinding(ebc).getAmountParams(verifyInfo.data[5]);
            require(ebc == ebcs[ap.ebcIndex - 1], "ENE");

            require(ap.chainIdIndex <= chainIds.length, "COF");
            destChainId = chainIds[ap.chainIdIndex - 1];
        }

        // Check dest token
        {
            require(verifyInfo.slots[4].account == _mdcFactory.manager(), "DTA");
            uint slotK = uint(abi.encode(abi.encode(uint64(destChainId), verifyInfo.data[10]).hash(), 3).hash());
            require(uint(verifyInfo.slots[4].key) == slotK + 1, "DTK");

            // TODO: At present, freezeToken and mainnetToken remain the same, and may change later
            require(
                _challenges[challengeId].statement[challenger].freezeToken ==
                    address(uint160(verifyInfo.slots[4].value)),
                "DTV"
            );
        }

        // Check _responseMakersHash
        {
            require(verifyInfo.slots[5].account == address(this), "RMHA");
            require(uint(verifyInfo.slots[5].key) == 5, "RMHK");
        }

        // Check ruleRoot key and rule
        {
            // Sure rule root storage position
            // Warnning: In the circuit, it is necessary to ensure that the rule exists in the mpt
            require(verifyInfo.slots[6].account == address(this), "RRA");
            uint slotK = uint(abi.encode(ebc, 6).hash());
            require(uint(verifyInfo.slots[6].key) == slotK, "RRK");

            // Rule
            require(uint(abi.encode(rule).hash()) == verifyInfo.data[8], "RH");
        }

        // Calculate dest amount
        // TODO: Is there a more general solution. Not only amount
        RuleLib.RuleOneway memory ro = RuleLib.convertToOneway(rule, uint64(verifyInfo.data[0]));
        uint destAmount = IOREventBinding(ebc).getResponseAmountFromIntent(
            IOREventBinding(ebc).getResponseIntent(verifyInfo.data[5], ro)
        );

        // Save tx'from address, and compensate tx'from on the mainnet when the maker failed
        _challenges[challengeId].statement[challenger].sourceTxFrom = verifyInfo.data[7];

        // Save manager._challengeUserRatio
        _challenges[challengeId].statement[challenger].challengeUserRatio = uint64(verifyInfo.slots[2].value >> 64);

        _challenges[challengeId].result.verifiedTime0 = uint64(block.timestamp);

        _challenges[challengeId].result.winner = challenger;

        // Save verified data's hash.
        // [minVerifyChallengeDestTxSecond, maxVerifyChallengeDestTxSecond, nonce, destChainId, destAddress, destToken, destAmount, responeMakersHash]
        _challenges[challengeId].result.verifiedDataHash0 = abi
            .encode(
                [
                    uint64(verifyInfo.slots[0].value >> 128),
                    uint64(verifyInfo.slots[0].value >> 128),
                    verifyInfo.data[0],
                    destChainId,
                    verifyInfo.data[9],
                    verifyInfo.data[10],
                    destAmount,
                    verifyInfo.slots[3].value
                ]
            )
            .hash();

        // TODO: add verify source gas cost (solt & emit)
        _challenges[challengeId].statement[challenger].challengerVerifyTransactionFee +=
            (uint128(startGasNum) -
                uint128(gasleft()) +
                uint128(IORManager(_mdcFactory.manager()).getChallengeBasefee())) *
            (uint128(block.basefee) + uint128(IORManager(_mdcFactory.manager()).getPriorityFee()));

        emit ChallengeInfoUpdated({
            challengeId: challengeId,
            statement: _challenges[challengeId].statement[challenger],
            result: _challenges[challengeId].result
        });
    }

    struct PublicInputData {
        uint64 sourceChainId;
        bytes32 sourceTxHash;
        uint256 txIndex;
        address from;
        address to;
        address token;
        uint256 amount;
        uint256 nonce;
        uint64 timestamp;
        address dest;
        address destToken;
        bytes32 L1TXBlockHash;
        uint256 L1TBlockNumber;
        address mdcContractAddress;
        address managerContractAddress;
    }

    function parsePublicInput(bytes calldata proofData) public pure returns (PublicInputData memory) {
        return
            PublicInputData({
                sourceChainId: uint64(uint256(bytes32(proofData[544:576]))),
                sourceTxHash: bytes32(
                    (uint256(bytes32(proofData[448:480])) << 128) | uint256(bytes32(proofData[480:512]))
                ),
                txIndex: uint256(bytes32(proofData[512:544])),
                from: address(uint160(uint256(bytes32(proofData[576:608])))),
                to: address(uint160(uint256(bytes32(proofData[608:640])))),
                token: address(uint160(uint256(bytes32(proofData[640:672])))),
                amount: uint256(bytes32(proofData[672:704])),
                nonce: uint256(bytes32(proofData[704:736])),
                timestamp: uint64(uint256(bytes32(proofData[736:768]))),
                dest: address(uint160(uint256(bytes32(proofData[768:800])))),
                destToken: address(uint160(uint256(bytes32(proofData[800:832])))),
                L1TXBlockHash: bytes32(
                    (uint256(bytes32(proofData[384:416])) << 128) | uint256(bytes32(proofData[416:448]))
                ),
                L1TBlockNumber: uint256(bytes32(proofData[1408:1440])),
                mdcContractAddress: address(uint160(uint256(bytes32(proofData[2560:2592])))),
                managerContractAddress: address(uint160(uint256(bytes32(proofData[2592:2624]))))
            });
    }

    function verifyChallengeSourceLaboratory(
        address spvAddress,
        address challenger,
        // bytes calldata publicInput, TODO: enable this argument after public input data is ready to hash encode
        bytes calldata proof
    ) external {
        uint256 startGasNum = gasleft();
        PublicInputData memory publicInputData = parsePublicInput(proof);
        require(
            (publicInputData.managerContractAddress == _mdcFactory.manager()) &&
                (publicInputData.mdcContractAddress == address(this)),
            "MCE"
        );
        BridgeLib.ChainInfo memory chainInfo = IORManager(publicInputData.managerContractAddress).getChainInfo(
            publicInputData.sourceChainId
        );
        require(chainInfo.spvs.includes(spvAddress), "SI"); // Invalid spv
        (bool success, ) = spvAddress.call(proof);
        require(success, "verify fail");
        // Check chainId, hash, timestamp
        bytes32 challengeId = abi.encode(publicInputData.sourceChainId, publicInputData.sourceTxHash).hash();
        ChallengeStatement memory statement = _challenges[challengeId].statement[challenger];
        ChallengeResult memory result = _challenges[challengeId].result;
        require(statement.challengeTime > 0, "CTZ");
        require(result.verifiedTime0 == 0, "VT0NZ");
        require(publicInputData.timestamp == statement.sourceTxTime, "ST");

        require(publicInputData.to == _owner, "TNEO");
    }

    /**
     *
     * @param spvAddress The spv's address
     * @param proof The zk's proof
     * @param spvBlockHashs If the blocks of the state proof and tx proof are not in the same segment, you need to verify the two blocks
     * @param verifyInfo The public inputs preimage for zk proofs
     *        verifyInfo.data: [chainId, txHash, from, to, token, amount, nonce, timestamp]
     *        verifyInfo.slots: [...see code]
     * @param verifiedData0 [minVerifyChallengeDestTxSecond, maxVerifyChallengeDestTxSecond, nonce, destChainId, destAddress, destToken, destAmount, responeMakersHash]
     * @param rawDatas The raw data list in preimage. [responeMakers]
     */
    function verifyChallengeDest(
        address spvAddress,
        address challenger,
        bytes calldata proof,
        bytes32[2] calldata spvBlockHashs,
        IORChallengeSpv.VerifyInfo calldata verifyInfo,
        uint[] calldata verifiedData0,
        bytes calldata rawDatas,
        uint64 sourceChainId
    ) external {
        require(IORChallengeSpv(spvAddress).verifyChallenge(proof, spvBlockHashs, abi.encode(verifyInfo).hash()), "VF");

        bytes32 challengeId = abi.encode(uint64(verifyInfo.data[0]), verifyInfo.data[1]).hash();
        require(_challenges[challengeId].result.verifiedTime0 > 0, "VT0Z");
        require(_challenges[challengeId].result.verifiedTime1 == 0, "VT1NZ");

        require(
            _getCanChallengeContinue(
                HelperLib.uint64ConcatToDecimal(
                    _challenges[challengeId].statement[challenger].sourceTxTime,
                    sourceChainId,
                    _challenges[challengeId].statement[challenger].sourceTxBlockNum,
                    _challenges[challengeId].statement[challenger].sourceTxIndex
                )
            ),
            "NCCF"
        );

        // Parse rawDatas
        uint[] memory responseMakers = abi.decode(rawDatas, (uint[]));

        // Check verifiedData0
        require(abi.encode(verifiedData0).hash() == _challenges[challengeId].result.verifiedDataHash0, "VDH0");
        require(abi.encode(responseMakers).hash() == bytes32(verifiedData0[7]), "RMH");

        // Check minVerifyChallengeDestTxSecond, maxVerifyChallengeDestTxSecond
        {
            uint timeDiff = block.timestamp - _challenges[challengeId].statement[challenger].sourceTxTime;
            require(timeDiff >= verifiedData0[0], "MINTOF");
            require(timeDiff <= verifiedData0[1], "MAXTOF");
        }

        // Check dest chainId
        require(verifyInfo.data[0] == verifiedData0[3], "DCID");

        // Check dest from address in responseMakers
        require(responseMakers.includes(verifyInfo.data[2]), "MIC");

        // Check dest address
        require(verifiedData0[4] == verifyInfo.data[3], "DADDR");

        // Check dest token
        require(verifiedData0[5] == verifyInfo.data[4], "DT");

        // Check dest amount (Warning: The nonce is at the end of the amount)
        require(verifiedData0[6] - verifiedData0[2] == verifyInfo.data[5], "DT");

        // TODO: check responseTime. Source tx timestamp may be more than dest tx timestamp.

        _challenges[challengeId].result.verifiedTime1 = uint64(block.timestamp);

        emit ChallengeInfoUpdated({
            challengeId: challengeId,
            statement: _challenges[challengeId].statement[msg.sender],
            result: _challenges[challengeId].result
        });
    }

    function _challengerFailed(
        ChallengeStatement memory challengeInfo,
        uint64 sourceChainId
    ) internal returns (uint256 unFreezeAmount) {
        unFreezeAmount = (challengeInfo.freezeAmount0 + challengeInfo.freezeAmount1);
        _challengeNodeList[
            HelperLib.uint64ConcatToDecimal(
                challengeInfo.sourceTxTime,
                sourceChainId,
                challengeInfo.sourceTxBlockNum,
                challengeInfo.sourceTxIndex
            )
        ].makerSuccessTime = uint64(block.timestamp);
    }

    function _unFreezeToken(address freezeToken, uint256 unFreezeAmount) internal {
        // Unfreeze
        if (unFreezeAmount > 0) {
            _freezeAssets[freezeToken] -= unFreezeAmount;
        }
    }

    function _makerFailed(
        ChallengeStatement memory challengeInfo,
        ChallengeStatement memory challengeInfoWinner,
        ChallengeResult memory result,
        address challenger,
        uint64 sourceChainId
    ) internal returns (uint256 unFreezeAmount) {
        unFreezeAmount = challengeInfo.freezeAmount0 + challengeInfo.freezeAmount1;
        if (result.winner == challenger) {
            uint challengeUserAmount = (challengeInfo.freezeAmount0 * challengeInfo.challengeUserRatio) /
                ConstantsLib.RATIO_MULTIPLE;
            require(challengeUserAmount <= challengeInfo.freezeAmount0, "UAOF");

            uint challengerAmount = unFreezeAmount - challengeUserAmount;
            _challengeNodeList[
                HelperLib.uint64ConcatToDecimal(
                    challengeInfo.sourceTxTime,
                    sourceChainId,
                    challengeInfo.sourceTxBlockNum,
                    challengeInfo.sourceTxIndex
                )
            ].makerFailedTime = uint64(block.timestamp);

            // TODO: Not compatible with starknet network
            address user = address(uint160(challengeInfo.sourceTxFrom));
            IERC20 token = IERC20(challengeInfo.freezeToken);

            if (challengeInfo.freezeToken == address(0)) {
                (bool sent1, ) = payable(user).call{value: challengeUserAmount}("");
                require(sent1, "ETH: SE1");

                (bool sent2, ) = payable(result.winner).call{
                    value: (challengerAmount +
                        MIN_CHALLENGE_DEPOSIT_AMOUNT +
                        challengeInfo.challengerVerifyTransactionFee)
                }("");
                require(sent2, "ETH: SE2");
            } else {
                token.safeTransfer(user, challengeUserAmount);
                token.safeTransfer(result.winner, challengerAmount);

                (bool sent3, ) = payable(result.winner).call{
                    value: MIN_CHALLENGE_DEPOSIT_AMOUNT + challengeInfo.challengerVerifyTransactionFee
                }("");
                require(sent3, "ETH: SE3");
            }
        } else if (_compareChallengerStatementHash(challengeInfo, challengeInfoWinner) == true) {
            (bool sent4, ) = payable(challenger).call{
                value: MIN_CHALLENGE_DEPOSIT_AMOUNT + challengeInfo.challengerVerifyTransactionFee
            }("");
            require(sent4, "ETH: SE4");
        }
    }

    function _compareChallengerStatementHash(
        ChallengeStatement memory challengeInfo,
        ChallengeStatement memory winner
    ) internal pure returns (bool) {
        return (challengeInfo.sourceTxFrom == winner.sourceTxFrom &&
            challengeInfo.sourceTxTime == winner.sourceTxTime &&
            challengeInfo.freezeToken == winner.freezeToken &&
            challengeInfo.challengeUserRatio == winner.challengeUserRatio &&
            challengeInfo.freezeAmount0 == winner.freezeAmount0);
    }
}
