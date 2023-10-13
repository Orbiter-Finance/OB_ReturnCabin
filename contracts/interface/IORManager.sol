// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BridgeLib} from "../library/BridgeLib.sol";

interface IORManager {
    event ChainInfoUpdated(uint64 indexed id, BridgeLib.ChainInfo chainInfo);
    event ChainTokenUpdated(uint64 indexed id, BridgeLib.TokenInfo tokenInfo);
    event EbcsUpdated(address[] ebcs, bool[] statuses);
    event SubmitterFeeUpdated(address submitter);
    event ProtocolFeeUpdated(uint64 protocolFee);
    event MinChallengeRatioUpdated(uint64 minChallengeRatio);
    event ChallengeUserRatioUpdated(uint64 challengeUserRatio);
    event FeeChallengeSecondUpdated(uint64 feeChallengeSecond);
    event FeeTakeOnChallengeSecondUpdated(uint64 feeTakeOnChallengeSecond);
    event MaxMDCLimitUpdated(uint64 maxMDCLimit);
    event ExtraTransferContractsUpdated(uint64[] chainIds, uint[] extraTransferContracts);

    function registerChains(uint64 enableTime, BridgeLib.ChainInfo[] calldata chains_) external;

    function getPriorityFee() external view returns (uint8);

    function updatePriorityFee(uint8 _priorityFee) external;

    function updateChainSpvs(uint64 enableTime, uint64 id, address[] calldata spvs, uint[] calldata indexs) external;

    function getChainInfo(uint64 id) external view returns (BridgeLib.ChainInfo memory);

    function updateChainTokens(
        uint64 enableTime,
        uint64[] memory ids,
        BridgeLib.TokenInfo[] calldata tokenInfos
    ) external;

    function getChainTokenInfo(uint64 id, uint token) external view returns (BridgeLib.TokenInfo memory);

    function ebcIncludes(address ebc) external view returns (bool);

    function updateEbcs(address[] calldata ebcs_, bool[] calldata statuses) external;

    function submitter() external view returns (address);

    function updateSubmitter(uint64 enableTime, address submitter_) external;

    function protocolFee() external view returns (uint64);

    function updateProtocolFee(uint64 enableTime, uint64 protocolFee_) external;

    function minChallengeRatio() external view returns (uint64);

    function updateMinChallengeRatio(uint64 enableTime, uint64 minChallengeRatio_) external;

    function challengeUserRatio() external view returns (uint64);

    function updateChallengeUserRatio(uint64 enableTime, uint64 challengeUserRatio_) external;

    function feeChallengeSecond() external view returns (uint64);

    function updateFeeChallengeSecond(uint64 enableTime, uint64 feeChallengeSecond_) external;

    function feeTakeOnChallengeSecond() external view returns (uint64);

    function updateFeeTakeOnChallengeSecond(uint64 enableTime, uint64 feeTakeOnChallengeSecond_) external;

    function maxMDCLimit() external view returns (uint64);

    function updateMaxMDCLimit(uint64 maxMDCLimit_) external;

    function getExtraTransferContract(uint64 chainId) external view returns (uint);

    function updateExtraTransferContracts(
        uint64 enableTime,
        uint64[] calldata chainIds,
        uint[] calldata extraTransferContracts
    ) external;
}
