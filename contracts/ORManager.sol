// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IORManager.sol";
import "./StorageVersion.sol";

contract ORManager is IORManager, Ownable, StorageVersion {
    // Ownable._owner use a slot
    // StorageVersion._storageVersion use a slot

    // Warning: the following order and type changes will cause state verification changes
    mapping(uint64 => BridgeLib.ChainInfo) private _chains;
    mapping(bytes32 => BridgeLib.TokenInfo) private _chainTokens; // hash(chainId, token) => TokenInfo
    mapping(address => bool) private _ebcs;
    address private _submitter;
    uint64 private _protocolFee;
    uint64 private _minChallengeRatio = 20000; // 10,000 percent
    uint64 private _challengeUserRatio; // 10,000 percent
    uint64 private _feeChallengeSecond;
    uint64 private _feeTakeOnChallengeSecond;
    uint64 private _maxMDCLimit = 2 ** 64 - 1;
    mapping(uint64 => uint) private _extraTransferContracts; // Cross-address transfer contracts. chainId => contractAddress

    constructor(address owner_) {
        require(owner_ != address(0), "OZ");
        _transferOwnership(owner_);
    }

    // TODO: setting the same chainId or token affect the protocol?
    function registerChains(BridgeLib.ChainInfo[] calldata chains_) external storageVersionIncrease onlyOwner {
        unchecked {
            for (uint i = 0; i < chains_.length; i++) {
                // TODO: There may be some settings that need to restrict modification

                // TODO: ORMakerDeposit.checkChallenge use maxVerifyChallengeSourceTxSecond, maxVerifyChallengeSourceTxSecond cannot be modified.
                //       Or make some adjustments when using

                _chains[chains_[i].id] = chains_[i];
                emit ChainInfoUpdated(chains_[i].id, chains_[i]);
            }
        }
    }

    function updateChainSpvs(
        uint64 id,
        address[] calldata spvs,
        uint[] calldata indexs
    ) external storageVersionIncrease onlyOwner {
        unchecked {
            for (uint i = 0; i < spvs.length; i++) {
                if (i < indexs.length) {
                    _chains[id].spvs[indexs[i]] = spvs[i];
                } else {
                    _chains[id].spvs.push(spvs[i]);
                }
            }
        }
        emit ChainInfoUpdated(id, _chains[id]);
    }

    function getChainInfo(uint64 id) external view returns (BridgeLib.ChainInfo memory) {
        return _chains[id];
    }

    function updateChainTokens(
        uint64[] calldata ids,
        BridgeLib.TokenInfo[] calldata tokenInfos
    ) external storageVersionIncrease onlyOwner {
        unchecked {
            for (uint i = 0; i < ids.length; i++) {
                bytes32 key = keccak256(abi.encodePacked(ids[i], tokenInfos[i].token));
                _chainTokens[key] = tokenInfos[i];
                emit ChainTokenUpdated(ids[i], tokenInfos[i]);
            }
        }
    }

    function getChainTokenInfo(uint64 id, uint token) external view returns (BridgeLib.TokenInfo memory) {
        bytes32 key = keccak256(abi.encodePacked(id, token));
        return _chainTokens[key];
    }

    function ebcIncludes(address ebc) external view returns (bool) {
        return _ebcs[ebc];
    }

    function updateEbcs(address[] calldata ebcs_, bool[] calldata statuses) external storageVersionIncrease onlyOwner {
        unchecked {
            for (uint i = 0; i < ebcs_.length; i++) {
                if (i < statuses.length) {
                    _ebcs[ebcs_[i]] = statuses[i];
                } else {
                    _ebcs[ebcs_[i]] = true;
                }
            }
        }
        emit EbcsUpdated(ebcs_, statuses);
    }

    function submitter() external view returns (address) {
        return _submitter;
    }

    function updateSubmitter(address submitter_) external storageVersionIncrease onlyOwner {
        _submitter = submitter_;
        emit SubmitterFeeUpdated(_submitter);
    }

    function protocolFee() external view returns (uint64) {
        return _protocolFee;
    }

    function updateProtocolFee(uint64 protocolFee_) external storageVersionIncrease onlyOwner {
        _protocolFee = protocolFee_;
        emit ProtocolFeeUpdated(_protocolFee);
    }

    function minChallengeRatio() external view returns (uint64) {
        return _minChallengeRatio;
    }

    function updateMinChallengeRatio(uint64 minChallengeRatio_) external storageVersionIncrease onlyOwner {
        _minChallengeRatio = minChallengeRatio_;
        emit MinChallengeRatioUpdated(_minChallengeRatio);
    }

    function challengeUserRatio() external view returns (uint64) {
        return _challengeUserRatio;
    }

    function updateChallengeUserRatio(uint64 challengeUserRatio_) external storageVersionIncrease onlyOwner {
        _challengeUserRatio = challengeUserRatio_;
        emit ChallengeUserRatioUpdated(_challengeUserRatio);
    }

    function feeChallengeSecond() external view returns (uint64) {
        return _feeChallengeSecond;
    }

    function updateFeeChallengeSecond(uint64 feeChallengeSecond_) external storageVersionIncrease onlyOwner {
        _feeChallengeSecond = feeChallengeSecond_;
        emit FeeChallengeSecondUpdated(_feeChallengeSecond);
    }

    function feeTakeOnChallengeSecond() external view returns (uint64) {
        return _feeTakeOnChallengeSecond;
    }

    function updateFeeTakeOnChallengeSecond(
        uint64 feeTakeOnChallengeSecond_
    ) external storageVersionIncrease onlyOwner {
        _feeTakeOnChallengeSecond = feeTakeOnChallengeSecond_;
        emit FeeTakeOnChallengeSecondUpdated(_feeTakeOnChallengeSecond);
    }

    function maxMDCLimit() external view returns (uint64) {
        return _maxMDCLimit;
    }

    function updateMaxMDCLimit(uint64 maxMDCLimit_) external storageVersionIncrease onlyOwner {
        _maxMDCLimit = maxMDCLimit_;
        emit MaxMDCLimitUpdated(_maxMDCLimit);
    }

    function getExtraTransferContract(uint64 chainId) external view returns (uint) {
        return _extraTransferContracts[chainId];
    }

    function updateExtraTransferContracts(
        uint64[] calldata chainIds,
        uint[] calldata extraTransferContracts
    ) external storageVersionIncrease onlyOwner {
        require(chainIds.length == extraTransferContracts.length, "CEOF");

        for (uint i = 0; i < chainIds.length; i++) {
            _extraTransferContracts[chainIds[i]] = extraTransferContracts[i];
        }
        emit ExtraTransferContractsUpdated(chainIds, extraTransferContracts);
    }
}
