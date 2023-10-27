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

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
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

        require(dealers.length < 100 && ebcs.length < 10 && chainIds.length < 100, "DECOF");

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

    function withdraw(address token, uint amount) external onlyOwner {
        if (token == address(0)) {
            require(address(this).balance - _freezeAssets[token] >= amount, "ETH: IF");

            (bool sent, ) = payable(msg.sender).call{value: amount}("");
            require(sent, "ETH: SE");
        } else {
            uint balance = IERC20(token).balanceOf(address(this));
            require(balance - _freezeAssets[token] >= amount, "ERC20: IF");

            IERC20(token).safeTransfer(msg.sender, amount);
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

    function challenge(
        uint64 sourceChainId,
        bytes32 sourceTxHash,
        uint64 sourceTxTime,
        address freezeToken,
        uint freezeAmount1
    ) external payable {
        bytes32 challengeId = abi.encode(sourceChainId, sourceTxHash).hash();
        require(_challenges[challengeId].challengeTime == 0, "CE");

        // Make sure the source timestamp is before the challenge
        require(uint64(block.timestamp) >= sourceTxTime, "STOF");

        if (freezeToken == address(0)) {
            require(freezeAmount1 == msg.value, "IF");
        } else {
            IERC20(freezeToken).safeTransferFrom(msg.sender, address(this), freezeAmount1);
        }

        // TODO: Currently it is assumed that the pledged assets of the challenger and the owner are the same
        uint freezeAmount0 = freezeAmount1;

        // Freeze mdc's owner assets and the assets in of challenger
        _freezeAssets[freezeToken] += freezeAmount0 + freezeAmount1;

        _challenges[challengeId] = ChallengeInfo(
            0,
            sourceTxTime,
            msg.sender,
            freezeToken,
            0,
            freezeAmount0,
            freezeAmount1,
            uint64(block.timestamp),
            0,
            0,
            0,
            0
        );

        emit ChallengeInfoUpdated(challengeId, _challenges[challengeId]);
    }

    function checkChallenge(uint64 sourceChainId, bytes32 sourceTxHash, uint[] calldata verifiedData0) external {
        bytes32 challengeId = abi.encode(uint64(sourceChainId), sourceTxHash).hash();
        ChallengeInfo memory challengeInfo = _challenges[challengeId];

        // Make sure the challenge exists
        require(challengeInfo.challengeTime > 0, "CNE");

        // Make sure verifyChallengeDest is not done yet
        require(challengeInfo.verifiedTime1 == 0, "VT1NZ");

        IORManager manager = IORManager(_mdcFactory.manager());

        if (challengeInfo.verifiedTime0 == 0) {
            BridgeLib.ChainInfo memory chainInfo = manager.getChainInfo(sourceChainId);

            require(block.timestamp > chainInfo.maxVerifyChallengeSourceTxSecond + challengeInfo.sourceTxTime, "VCST");

            _challengerFailed(challengeInfo);
            delete _challenges[challengeId];
        } else {
            // Ensure the correctness of verifiedData0
            require(abi.encode(verifiedData0).hash() == challengeInfo.verifiedDataHash0, "VDH");

            BridgeLib.ChainInfo memory chainInfo = manager.getChainInfo(uint64(verifiedData0[0]));
            require(block.timestamp > chainInfo.maxVerifyChallengeDestTxSecond + challengeInfo.sourceTxTime, "VCDT");

            _makerFailed(challengeInfo);
        }
        _challenges[challengeId].abortTime = uint64(block.timestamp);

        emit ChallengeInfoUpdated(challengeId, _challenges[challengeId]);
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
        bytes calldata proof,
        bytes32[2] calldata spvBlockHashs,
        IORChallengeSpv.VerifyInfo calldata verifyInfo,
        bytes calldata rawDatas
    ) external {
        BridgeLib.ChainInfo memory chainInfo = IORManager(_mdcFactory.manager()).getChainInfo(
            uint64(verifyInfo.data[0])
        );
        require(chainInfo.spvs.includes(spvAddress), "SI"); // Invalid spv
        require(IORChallengeSpv(spvAddress).verifyChallenge(proof, spvBlockHashs, abi.encode(verifyInfo).hash()), "VF");

        // Check chainId, hash, timestamp
        bytes32 challengeId = abi.encode(uint64(verifyInfo.data[0]), verifyInfo.data[1]).hash();
        require(_challenges[challengeId].challengeTime > 0, "CTZ");
        require(_challenges[challengeId].verifiedTime0 == 0, "VT0NZ");
        require(uint64(verifyInfo.data[7]) == _challenges[challengeId].sourceTxTime, "ST");

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
            require(_challenges[challengeId].freezeToken == address(uint160(verifyInfo.slots[1].value)), "FTV");

            // FreezeAmount
            require(verifyInfo.slots[2].account == _mdcFactory.manager(), "FAA");
            require(uint(verifyInfo.slots[2].key) == 6, "FAK");
            uint64 _minChallengeRatio = uint64(verifyInfo.slots[2].value);
            require(
                _challenges[challengeId].freezeAmount1 >=
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
            require(_challenges[challengeId].freezeToken == address(uint160(verifyInfo.slots[4].value)), "DTV");
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
        _challenges[challengeId].sourceTxFrom = verifyInfo.data[7];

        // Save manager._challengeUserRatio
        _challenges[challengeId].challengeUserRatio = uint64(verifyInfo.slots[2].value >> 64);

        _challenges[challengeId].verifiedTime0 = uint64(block.timestamp);

        // Save verified data's hash.
        // [minVerifyChallengeDestTxSecond, maxVerifyChallengeDestTxSecond, nonce, destChainId, destAddress, destToken, destAmount, responeMakersHash]
        _challenges[challengeId].verifiedDataHash0 = abi
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

        emit ChallengeInfoUpdated(challengeId, _challenges[challengeId]);
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
        bytes calldata proof,
        bytes32[2] calldata spvBlockHashs,
        IORChallengeSpv.VerifyInfo calldata verifyInfo,
        uint[] calldata verifiedData0,
        bytes calldata rawDatas
    ) external {
        require(IORChallengeSpv(spvAddress).verifyChallenge(proof, spvBlockHashs, abi.encode(verifyInfo).hash()), "VF");

        bytes32 challengeId = abi.encode(uint64(verifyInfo.data[0]), verifyInfo.data[1]).hash();
        require(_challenges[challengeId].verifiedTime0 > 0, "VT0Z");
        require(_challenges[challengeId].verifiedTime1 == 0, "VT1NZ");

        // Parse rawDatas
        uint[] memory responseMakers = abi.decode(rawDatas, (uint[]));

        // Check verifiedData0
        require(abi.encode(verifiedData0).hash() == _challenges[challengeId].verifiedDataHash0, "VDH0");
        require(abi.encode(responseMakers).hash() == bytes32(verifiedData0[7]), "RMH");

        // Check minVerifyChallengeDestTxSecond, maxVerifyChallengeDestTxSecond
        {
            uint timeDiff = block.timestamp - _challenges[challengeId].sourceTxTime;
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

        _challengerFailed(_challenges[challengeId]);

        _challenges[challengeId].verifiedTime1 = uint64(block.timestamp);

        emit ChallengeInfoUpdated(challengeId, _challenges[challengeId]);
    }

    function _challengerFailed(ChallengeInfo memory challengeInfo) internal {
        // Unfreeze
        _freezeAssets[challengeInfo.freezeToken] -= (challengeInfo.freezeAmount0 + challengeInfo.freezeAmount1);
    }

    function _makerFailed(ChallengeInfo memory challengeInfo) internal {
        uint challengeUserAmount = (challengeInfo.freezeAmount0 * challengeInfo.challengeUserRatio) /
            ConstantsLib.RATIO_MULTIPLE;
        require(challengeUserAmount <= challengeInfo.freezeAmount0, "UAOF");

        uint challengerAmount = challengeInfo.freezeAmount0 + challengeInfo.freezeAmount1 - challengeUserAmount;

        // TODO: Not compatible with starknet network
        address user = address(uint160(challengeInfo.sourceTxFrom));

        if (challengeInfo.freezeToken == address(0)) {
            (bool sent1, ) = payable(user).call{value: challengeUserAmount}("");
            require(sent1, "ETH: SE1");

            (bool sent2, ) = payable(challengeInfo.challenger).call{value: challengerAmount}("");
            require(sent2, "ETH: SE2");
        } else {
            IERC20(challengeInfo.freezeToken).safeTransfer(user, challengeUserAmount);

            IERC20(challengeInfo.freezeToken).safeTransfer(challengeInfo.challenger, challengerAmount);
        }

        // Unfreeze
        _freezeAssets[challengeInfo.freezeToken] -= (challengeInfo.freezeAmount0 + challengeInfo.freezeAmount1);
    }
}
