// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BridgeLib} from "../library/BridgeLib.sol";
import {RuleLib} from "../library/RuleLib.sol";

interface IORMakerDeposit {
    struct ChallengeInfo {
        address challenger; // Challenger
        address freezeToken; // Freeze token on L1
        uint freezeAmount0; // Owner's freeze amount
        uint freezeAmount1; // Challenger's freeze amount
        uint64 challengeTime; // Time of challenge
        uint64 abortTime; // Time of abort caused by checkChallenge
        uint64 verifiedTime0; // Time of verifyChallengeSource. Greater than 0 means verification passed
        uint64 verifiedTime1; // Time of verifyChallengeDest. Greater than 0 means verification passed
        bytes32 verifiedDataHash0; // Data's hash of verifyChallengeSource
    }

    event ColumnArrayUpdated(
        address indexed impl,
        bytes32 columnArrayHash,
        address[] dealers,
        address[] ebcs,
        uint64[] chainIds
    );
    event SpvUpdated(address indexed impl, uint64 chainId, address spv);
    event ResponseMakersUpdated(address indexed impl, address[] responseMakers);
    event RulesRootUpdated(address indexed impl, address ebc, RuleLib.RootWithVersion rootWithVersion);

    function initialize(address owner_) external;

    function owner() external view returns (address);

    function mdcFactory() external view returns (address);

    function columnArrayHash() external view returns (bytes32);

    function updateColumnArray(
        address[] calldata dealers,
        address[] calldata ebcs,
        uint64[] calldata chainIds
    ) external;

    function spv(uint64 chainId) external view returns (address);

    function updateSpvs(address[] calldata spvs, uint64[] calldata chainIds) external;

    function responseMakers() external view returns (address[] memory);

    function updateResponseMakers(address[] calldata responseMakers_, uint[] calldata indexs) external;

    function freezeAssets(address token) external view returns (uint);

    function deposit(address token, uint amount) external payable;

    function withdraw(address token, uint amount) external;

    function rulesRoot(address ebc) external view returns (RuleLib.RootWithVersion memory);

    function updateRulesRoot(
        address ebc,
        bytes calldata rsc,
        RuleLib.RootWithVersion calldata rootWithVersion,
        uint64[] calldata sourceChainIds,
        uint[] calldata pledgeAmounts
    ) external payable;

    function updateRulesRootERC20(
        address ebc,
        bytes calldata rsc,
        RuleLib.RootWithVersion calldata rootWithVersion,
        uint64[] calldata sourceChainIds,
        uint[] calldata pledgeAmounts,
        address token
    ) external;
}
