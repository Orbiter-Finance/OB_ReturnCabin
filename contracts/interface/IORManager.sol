// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operations.sol";

interface IORManager {
    event ChainInfoUpdated(uint indexed id, OperationsLib.ChainInfo chainInfo);
    event SubmitterFeeUpdated(address submitter);
    event ProtocolFeeUpdated(uint64 protocolFee);
    event MinChallengeRatioUpdated(uint64 minChallengeRatio);
    event ChallengeUserRatioUpdated(uint64 challengeUserRatio);
    event FeeManagerChallengeSecondUpdated(uint64 feeManagerChallengeSecond);
    event FeeManagerTakeOnChallengeSecondUpdated(uint64 feeManagerTakeOnChallengeSecond);
    event MakerMaxLimitUpdated(uint64 makerMaxLimit);

    function registerChains(OperationsLib.ChainInfo[] calldata chains_) external;

    function updateChainSpvs(uint id, address[] calldata spvs, uint[] calldata indexs) external;

    function updateChainTokens(uint id, OperationsLib.TokenInfo[] calldata token, uint[] calldata indexs) external;

    function getChainInfo(uint id) external view returns (OperationsLib.ChainInfo memory chainInfo);

    function submitter() external view returns (address);

    function updateSubmitter(address submitter_) external;

    function protocolFee() external view returns (uint64);

    function updateProtocolFee(uint64 protocolFee_) external;

    function minChallengeRatio() external view returns (uint64);

    function updateMinChallengeRatio(uint64 minChallengeRatio_) external;

    function challengeUserRatio() external view returns (uint64);

    function updateChallengeUserRatio(uint64 challengeUserRatio_) external;

    function feeManagerChallengeSecond() external view returns (uint64);

    function updateFeeManagerChallengeSecond(uint64 feeManagerChallengeSecond_) external;

    function feeManagerTakeOnChallengeSecond() external view returns (uint64);

    function updateFeeManagerTakeOnChallengeSecond(uint64 feeManagerTakeOnChallengeSecond_) external;

    function makerMaxLimit() external view returns (uint64);

    function updateMakerMaxLimit(uint64 makerMaxLimit_) external;
}
