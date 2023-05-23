// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/IORManager.sol";
import "./interface/IORProtocal.sol";
import "./Multicall.sol";

contract ORManager is IORManager, Ownable, Multicall {
    mapping(uint => OperationsLib.ChainInfo) private _chains;
    address private _submitter;
    uint64 private _protocolFee;
    uint64 private _minChallengeRatio = 200;
    uint64 private _challengeUserRatio;
    uint64 private _feeManagerChallengeSecond;
    uint64 private _feeManagerTakeOnChallengeSecond;
    uint64 private _makerMaxLimit;

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    // TODO: setting the same chainId or token affect the protocol?
    function registerChains(OperationsLib.ChainInfo[] calldata chains_) external onlyOwner {
        unchecked {
            for (uint i = 0; i < chains_.length; i++) {
                _chains[chains_[i].id] = chains_[i];
                emit ChainInfoUpdated(chains_[i].id, chains_[i]);
            }
        }
    }

    function updateChainSpvs(uint id, address[] calldata spvs, uint[] calldata indexs) external onlyOwner {
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

    function updateChainTokens(
        uint id,
        OperationsLib.TokenInfo[] calldata tokens,
        uint[] calldata indexs
    ) external onlyOwner {
        unchecked {
            for (uint i = 0; i < tokens.length; i++) {
                if (i < indexs.length) {
                    _chains[id].tokens[indexs[i]] = tokens[i];
                } else {
                    _chains[id].tokens.push(tokens[i]);
                }
            }
        }
        emit ChainInfoUpdated(id, _chains[id]);
    }

    function getChainInfo(uint id) external view returns (OperationsLib.ChainInfo memory chainInfo) {
        chainInfo = _chains[id];
    }

    function submitter() external view returns (address) {
        return _submitter;
    }

    function updateSubmitter(address submitter_) external onlyOwner {
        _submitter = submitter_;
        emit SubmitterFeeUpdated(_submitter);
    }

    function protocolFee() external view returns (uint64) {
        return _protocolFee;
    }

    function updateProtocolFee(uint64 protocolFee_) external onlyOwner {
        _protocolFee = protocolFee_;
        emit ProtocolFeeUpdated(_protocolFee);
    }

    function minChallengeRatio() external view returns (uint64) {
        return _minChallengeRatio;
    }

    function updateMinChallengeRatio(uint64 minChallengeRatio_) external onlyOwner {
        _minChallengeRatio = minChallengeRatio_;
        emit MinChallengeRatioUpdated(minChallengeRatio_);
    }

    function challengeUserRatio() external view returns (uint64) {
        return _challengeUserRatio;
    }

    function updateChallengeUserRatio(uint64 challengeUserRatio_) external onlyOwner {
        _challengeUserRatio = challengeUserRatio_;
        emit ChallengeUserRatioUpdated(challengeUserRatio_);
    }

    function feeManagerChallengeSecond() external view returns (uint64) {
        return _feeManagerChallengeSecond;
    }

    function updateFeeManagerChallengeSecond(uint64 feeManagerChallengeSecond_) external onlyOwner {
        _feeManagerChallengeSecond = feeManagerChallengeSecond_;
        emit FeeManagerChallengeSecondUpdated(feeManagerChallengeSecond_);
    }

    function feeManagerTakeOnChallengeSecond() external view returns (uint64) {
        return _feeManagerTakeOnChallengeSecond;
    }

    function updateFeeManagerTakeOnChallengeSecond(uint64 feeManagerTakeOnChallengeSecond_) external onlyOwner {
        _feeManagerTakeOnChallengeSecond = feeManagerTakeOnChallengeSecond_;
        emit FeeManagerTakeOnChallengeSecondUpdated(feeManagerTakeOnChallengeSecond_);
    }

    function makerMaxLimit() external view returns (uint64) {
        return _makerMaxLimit;
    }

    function updateMakerMaxLimit(uint64 makerMaxLimit_) external onlyOwner {
        _makerMaxLimit = makerMaxLimit_;
        emit MakerMaxLimitUpdated(makerMaxLimit_);
    }
}
