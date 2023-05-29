// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operations.sol";

interface IORManager {
    event ChainInfoUpdated(uint indexed id, OperationsLib.ChainInfo chainInfo);
    event EbcsUpdated(address[] ebcs);
    event SubmitterFeeUpdated(address submitter);
    event ProtocolFeeUpdated(uint64 protocolFee);
    event MinChallengeRatioUpdated(uint64 minChallengeRatio);
    event ChallengeUserRatioUpdated(uint64 challengeUserRatio);
    event FeeChallengeSecondUpdated(uint64 feeChallengeSecond);
    event FeeTakeOnChallengeSecondUpdated(uint64 feeTakeOnChallengeSecond);
    event MaxMDCLimitUpdated(uint64 maxMDCLimit);

    function registerChains(OperationsLib.ChainInfo[] calldata chains_) external;

    function updateChainSpvs(uint16 id, address[] calldata spvs, uint[] calldata indexs) external;

    function updateChainTokens(uint16 id, OperationsLib.TokenInfo[] calldata token, uint[] calldata indexs) external;

    function getChainInfo(uint16 id) external view returns (OperationsLib.ChainInfo memory);

    function ebcs() external view returns (address[] memory);

    function updateEbcs(address[] calldata ebcs_, uint[] calldata indexs) external;

    function submitter() external view returns (address);

    function updateSubmitter(address submitter_) external;

    function protocolFee() external view returns (uint64);

    function updateProtocolFee(uint64 protocolFee_) external;

    function minChallengeRatio() external view returns (uint64);

    function updateMinChallengeRatio(uint64 minChallengeRatio_) external;

    function challengeUserRatio() external view returns (uint64);

    function updateChallengeUserRatio(uint64 challengeUserRatio_) external;

    function feeChallengeSecond() external view returns (uint64);

    function updateFeeChallengeSecond(uint64 feeChallengeSecond_) external;

    function feeTakeOnChallengeSecond() external view returns (uint64);

    function updateFeeTakeOnChallengeSecond(uint64 feeTakeOnChallengeSecond_) external;

    function maxMDCLimit() external view returns (uint64);

    function updateMaxMDCLimit(uint64 maxMDCLimit_) external;
}
