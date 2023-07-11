// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IORMakerDeposit.sol";
import "./interface/IORManager.sol";
import "./interface/IORMDCFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ArrayLib} from "./library/ArrayLib.sol";
import {RuleLib} from "./library/RuleLib.sol";
import {ConstantsLib} from "./library/ConstantsLib.sol";
import {IORChallengeSpv} from "./interface/IORChallengeSpv.sol";
import {IOREventBinding} from "./interface/IOREventBinding.sol";

// TODO: for dev
// import "hardhat/console.sol";

contract ORMakerDeposit is IORMakerDeposit {
    using ArrayLib for address[];
    using SafeERC20 for IERC20;

    address private _owner;
    IORMDCFactory private _mdcFactory;
    bytes32 private _columnArrayHash;
    mapping(uint32 => address) private _spvs; // chainId => spvAddress
    address[] private _responseMakers; // Response maker list, not just owner, to improve tps
    mapping(address => RuleLib.RootWithVersion) private _rulesRoots; // ebc => merkleRoot(rules), version
    mapping(address => mapping(bytes32 => uint)) private _pledgeBalances; // ebc => hash(sourceChainId, sourceToken) => pledgeBalance
    mapping(address => uint) private _freezeAssets; // token(ETH: 0) => freezeAmount
    mapping(bytes32 => ChallengeInfo) private _challenges; // hash(sourceChainId, transactionHash) => ChallengeInfo

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

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
        address[] calldata dealers,
        address[] calldata ebcs,
        uint32[] calldata chainIds
    ) external onlyOwner {
        require(dealers.length <= 10, "DOF");
        require(ebcs.length <= 10, "EOF");
        require(chainIds.length <= 100, "COF");

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

        _columnArrayHash = keccak256(abi.encodePacked(dealers, ebcs, chainIds));

        address impl = _mdcFactory.implementation();
        emit ColumnArrayUpdated(impl, _columnArrayHash, dealers, ebcs, chainIds);
    }

    function spv(uint32 chainId) external view returns (address) {
        return _spvs[chainId];
    }

    function updateSpvs(address[] calldata spvs, uint32[] calldata chainIds) external onlyOwner {
        IORManager manager = IORManager(_mdcFactory.manager());
        address impl = _mdcFactory.implementation();

        for (uint i = 0; i < chainIds.length; i++) {
            BridgeLib.ChainInfo memory chainInfo = manager.getChainInfo(chainIds[i]);
            require(chainInfo.id > 0, "CI"); // Invalid chainId

            require(chainInfo.spvs.addressIncludes(spvs[i]), "SI"); // Invalid spv

            _spvs[chainIds[i]] = spvs[i];

            emit SpvUpdated(impl, chainIds[i], spvs[i]);
        }
    }

    function responseMakers() external view returns (address[] memory) {
        return _responseMakers;
    }

    // TODO: Not compatible with starknet network
    function updateResponseMakers(address[] calldata responseMakers_, uint[] calldata indexs) external onlyOwner {
        unchecked {
            for (uint i = 0; i < responseMakers_.length; i++) {
                if (i < indexs.length) {
                    _responseMakers[indexs[i]] = responseMakers_[i];
                } else {
                    _responseMakers.push(responseMakers_[i]);
                }
            }
        }
        emit ResponseMakersUpdated(_mdcFactory.implementation(), _responseMakers);
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
        address ebc,
        bytes calldata rsc,
        RuleLib.RootWithVersion calldata rootWithVersion,
        uint32[] calldata sourceChainIds,
        uint[] calldata pledgeAmounts
    ) external payable onlyOwner {
        // Prevent unused hints
        rsc;

        _updateRulesRoot(ebc, rootWithVersion);

        require(sourceChainIds.length == pledgeAmounts.length, "SPL");

        uint totalAmount;
        for (uint i = 0; i < sourceChainIds.length; ) {
            bytes32 k = keccak256(abi.encodePacked(sourceChainIds[i], address(0)));

            if (pledgeAmounts[i] > _pledgeBalances[ebc][k]) {
                totalAmount += pledgeAmounts[i] - _pledgeBalances[ebc][k];
            }

            _pledgeBalances[ebc][k] = pledgeAmounts[i];

            unchecked {
                i++;
            }
        }

        require(totalAmount <= msg.value, "IV"); // Insufficient value
    }

    function updateRulesRootERC20(
        address ebc,
        bytes calldata rsc,
        RuleLib.RootWithVersion calldata rootWithVersion,
        uint32[] calldata sourceChainIds,
        uint[] calldata pledgeAmounts,
        address token
    ) external onlyOwner {
        // Prevent unused hints
        rsc;

        _updateRulesRoot(ebc, rootWithVersion);

        require(sourceChainIds.length == pledgeAmounts.length, "SPL");

        for (uint i = 0; i < sourceChainIds.length; ) {
            bytes32 k = keccak256(abi.encodePacked(sourceChainIds[i], token));

            if (pledgeAmounts[i] > _pledgeBalances[ebc][k]) {
                IERC20(token).safeTransferFrom(msg.sender, address(this), pledgeAmounts[i] - _pledgeBalances[ebc][k]);
            }

            unchecked {
                i++;
            }
        }
    }

    function _updateRulesRoot(address ebc, RuleLib.RootWithVersion calldata rootWithVersion) private {
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
        uint32 sourceChainId,
        bytes32 sourceTxHash,
        address freezeToken,
        uint freezeAmount1
    ) external payable {
        bytes32 k = keccak256(abi.encodePacked(sourceChainId, sourceTxHash));
        require(_challenges[k].challengeTime == 0, "CE");

        if (freezeToken == address(0)) {
            require(freezeAmount1 == msg.value, "IF");
        } else {
            IERC20(freezeToken).safeTransferFrom(msg.sender, address(this), freezeAmount1);
        }

        // TODO: Currently it is assumed that the pledged assets of the challenger and the owner are the same
        uint freezeAmount0 = freezeAmount1;

        // Freeze mdc's owner assets and the assets in of challenger
        _freezeAssets[freezeToken] += freezeAmount0 + freezeAmount1;

        _challenges[k] = ChallengeInfo(freezeToken, freezeAmount0, freezeAmount1, uint64(block.timestamp), 0, 0, 0);

        // TODO: emit event
    }

    function checkChallenge(bytes32 challengeId) external {
        // TODO: state machine
    }

    /**
     *
     * @param spvAddress The spv's address
     * @param proof The zk's proof
     * @param spvBlockHash The block hash used for the proof
     * @param verifyInfo The public inputs preimage for zk proofs
     *        verifyInfo.data: [chainId, txHash, from, to, token, amount, nonce, timestamp, ruleHash]
     *        verifyInfo.slots: [this._columnArrayHash, Manager._chains, this._rulesRoots]
     * @param rawDatas The raw data list in preimage. [dealers, ebcs, chainIds, ebc, ...]
     */
    function verifyChallengeSource(
        address spvAddress,
        bytes calldata proof,
        bytes32 spvBlockHash,
        IORChallengeSpv.VerifyInfo calldata verifyInfo,
        bytes calldata rawDatas
    ) external {
        bytes32 verifyInfoHash = keccak256(abi.encode(verifyInfo));

        bool result = IORChallengeSpv(spvAddress).verifyChallenge(proof, spvBlockHash, verifyInfoHash);
        require(result, "VF");

        // Check chainId, hash
        bytes32 challengeId = keccak256(abi.encodePacked(uint32(verifyInfo.data[0]), verifyInfo.data[1]));
        require(_challenges[challengeId].challengeTime > 0, "CTZ");
        require(_challenges[challengeId].verifiedTime0 == 0, "VT0NZ");

        // Check to address == owner
        // TODO: Not compatible with starknet network
        require(uint160(verifyInfo.data[2]) == uint160(_owner), "TNEO");

        // Parse rawDatas
        (
            address[] memory dealers,
            address[] memory ebcs,
            uint32[] memory chainIds,
            address ebc,
            RuleLib.Rule memory rule
        ) = abi.decode(rawDatas, (address[], address[], uint32[], address, RuleLib.Rule));

        // Check manager's chainInfo.minVerifyChallengeSourceTxSecond,maxVerifyChallengeSourceTxSecond
        {
            require(verifyInfo.slots[0].account == _mdcFactory.manager(), "VCSTA");
            uint slotK = uint(keccak256(abi.encode(verifyInfo.data[0], 0))); // abi.encode no need to convert type
            require(uint(verifyInfo.slots[0].key) == slotK + 2, "VCSTK");

            uint timeDiff = block.timestamp - verifyInfo.data[7];
            require(timeDiff >= ((verifyInfo.slots[0].value << 192) >> 192), "MINTOF");
            require(timeDiff <= ((verifyInfo.slots[0].value << 128) >> 192), "MAXTOF");
        }

        // Check freezeToken and freezeAmount
        {
            // FreezeToken
            require(verifyInfo.slots[1].account == _mdcFactory.manager(), "FTA");
            uint slotK = uint(
                keccak256(abi.encode(keccak256(abi.encodePacked(uint32(verifyInfo.data[0]), verifyInfo.data[4])), 1))
            );
            require(uint(verifyInfo.slots[1].key) == slotK + 1, "FTK");
            require(_challenges[challengeId].freezeToken == address(uint160(verifyInfo.slots[1].value)), "FTV");

            // FreezeAmount
            require(verifyInfo.slots[2].account == _mdcFactory.manager(), "FAA");
            require(uint(verifyInfo.slots[2].key) == 4, "FAK");
            uint64 _minChallengeRatio = uint64(verifyInfo.slots[2].value >> 192);
            require(
                _challenges[challengeId].freezeAmount1 >= (verifyInfo.data[5] * _minChallengeRatio) / 10000,
                "FALV"
            );
        }

        // Check _columnArrayHash at the spvBlockHash
        {
            bytes32 cah = keccak256(abi.encodePacked(dealers, ebcs, chainIds));
            require(verifyInfo.slots[2].account == address(this), "CAHA");
            require(verifyInfo.slots[2].key == ConstantsLib.STORAGE_KEY_TWO, "CAHK");
            require(bytes32(verifyInfo.slots[2].value) == cah, "CAHV");
        }

        // Check ebc address
        {
            uint[] memory splits = IOREventBinding(ebc).splitSecurityCodeFromAmount(verifyInfo.data[5]);
            require(ebc == ebcs[splits[1]], "ENE");
        }

        // Check ruleRoot key and rule
        {
            // Rule root
            require(verifyInfo.slots[3].account == address(this), "RRA");
            uint slotK2 = uint(keccak256(abi.encode(ebc, 5)));
            require(uint(verifyInfo.slots[3].key) == slotK2, "RRK");

            // Rule
            require(uint(keccak256(abi.encode(rule))) == verifyInfo.data[8], "RH");
        }

        _challenges[challengeId].verifiedTime0 = uint64(block.timestamp);

        // TODO: Save verified data's hash. [nonce, destChainId, destAmount, responeMakers]

        // TODO: emit events
    }

    function verifyChallengeDest(
        address spvAddress,
        bytes calldata proof,
        bytes32 spvBlockHash,
        IORChallengeSpv.VerifyInfo calldata verifyInfo,
        uint[] calldata verifiedData0
    ) external {
        bytes32 verifyInfoHash = keccak256(abi.encode(verifyInfo));

        bool result = IORChallengeSpv(spvAddress).verifyChallenge(proof, spvBlockHash, verifyInfoHash);
        require(result, "VF");

        bytes32 challengeId = keccak256(abi.encodePacked(uint32(verifyInfo.data[0]), verifyInfo.data[1]));
        require(_challenges[challengeId].verifiedTime0 > 0, "VT0Z");
        require(_challenges[challengeId].verifiedTime1 == 0, "VT1NZ");

        // TODO, check chainInfo.minVerifyChallengeDestTxSecond, maxVerifyChallengeDestTxSecond

        // TODO: Check the address and key of the slot

        bytes32 verifiedDataHash0 = keccak256(abi.encode(verifiedData0));
        require(_challenges[challengeId].verifiedDataHash0 == verifiedDataHash0, "VDHI");

        _challenges[challengeId].verifiedTime1 = uint64(block.timestamp);

        // TODO: Confiscate challenger assets and unfreeze owner assets

        // TODO: emit events
    }
}
