// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BridgeLib} from "../library/BridgeLib.sol";

interface IORManager {
    event ChainInfoUpdated(uint32 indexed id, BridgeLib.ChainInfo chainInfo);
    event ChainTokenUpdated(uint32 indexed id, BridgeLib.TokenInfo tokenInfo);
    event EbcsUpdated(address[] ebcs, bool[] statuses);
    event SubmitterFeeUpdated(address submitter);
    event ProtocolFeeUpdated(uint64 protocolFee);
    event MinChallengeRatioUpdated(uint64 minChallengeRatio);
    event ChallengeUserRatioUpdated(uint64 challengeUserRatio);
    event FeeChallengeSecondUpdated(uint64 feeChallengeSecond);
    event FeeTakeOnChallengeSecondUpdated(uint64 feeTakeOnChallengeSecond);
    event MaxMDCLimitUpdated(uint64 maxMDCLimit);

    function registerChains(BridgeLib.ChainInfo[] calldata chains_) external;

    function updateChainSpvs(uint32 id, address[] calldata spvs, uint[] calldata indexs) external;

    function getChainInfo(uint32 id) external view returns (BridgeLib.ChainInfo memory);

    function updateChainTokens(uint32[] memory ids, BridgeLib.TokenInfo[] calldata tokenInfos) external;

    function getChainTokenInfo(uint32 id, uint token) external view returns (BridgeLib.TokenInfo memory);

    function ebcIncludes(address ebc) external view returns (bool);

    function updateEbcs(address[] calldata ebcs_, bool[] calldata statuses) external;

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
