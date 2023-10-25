// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORChallengeSpv} from "./IORChallengeSpv.sol";
import {BridgeLib} from "../library/BridgeLib.sol";
import {RuleLib} from "../library/RuleLib.sol";

interface IORMakerDeposit {
    struct ChallengeInfo {
        uint sourceTxFrom; // From of the source tx. Uint to support other networks
        uint64 sourceTxTime; // Timestamp of the source tx
        address challenger; // Challenger
        address freezeToken; // Freeze token on L1
        uint64 challengeUserRatio; // Manager's _challengeUserRatio
        uint freezeAmount0; // Owner's freeze amount
        uint freezeAmount1; // Challenger's freeze amount
        uint64 challengeTime; // Time of challenge
        uint64 abortTime; // Time of abort caused by checkChallenge
        uint64 verifiedTime0; // Time of verifyChallengeSource. Greater than 0 means verification passed
        uint64 verifiedTime1; // Time of verifyChallengeDest. Greater than 0 means verification passed
        bytes32 verifiedDataHash0; // Data's hash of verifyChallengeSource
        uint challengerVerifyGasUsed; // Gas used of challenger verify
        uint64 challengeIdentNum;
    }

    struct ChallengeNode {
        uint64 next;
        uint32 verifyCount;
    }

    struct WithdrawRequestInfo {
        uint requestAmount;
        uint64 requestTimestamp;
        address requestToken;
    }

    event WithdrawRequested(uint requestAmount, uint64 requestTimestamp, address requestToken);

    event ColumnArrayUpdated(
        address indexed impl,
        bytes32 columnArrayHash,
        address[] dealers,
        address[] ebcs,
        uint64[] chainIds
    );
    event SpvUpdated(address indexed impl, uint64 chainId, address spv);
    event ResponseMakersUpdated(address indexed impl, uint[] responseMakers);
    event RulesRootUpdated(address indexed impl, address ebc, RuleLib.RootWithVersion rootWithVersion);
    event ChallengeInfoUpdated(bytes32 indexed challengeId, ChallengeInfo challengeInfo);

    function initialize(address owner_) external;

    function owner() external view returns (address);

    function mdcFactory() external view returns (address);

    function columnArrayHash() external view returns (bytes32);

    function updateColumnArray(
        uint64 enableTime,
        address[] calldata dealers,
        address[] calldata ebcs,
        uint64[] calldata chainIds
    ) external;

    function spv(uint64 chainId) external view returns (address);

    function updateSpvs(uint64 enableTime, address[] calldata spvs, uint64[] calldata chainIds) external;

    function responseMakersHash() external view returns (bytes32);

    function updateResponseMakers(uint64 enableTime, bytes[] calldata responseMakerSignatures) external;

    function freezeAssets(address token) external view returns (uint);

    function deposit(address token, uint amount) external payable;

    function getWithdrawRequestInfo(address targetToken) external view returns (WithdrawRequestInfo memory);

    function withdrawRequest(address requestToken, uint requestAmount) external;

    function withdraw(address token) external;

    function rulesRoot(address ebc) external view returns (RuleLib.RootWithVersion memory);

    function updateRulesRoot(
        uint64 enableTime,
        address ebc,
        RuleLib.Rule[] calldata rules,
        RuleLib.RootWithVersion calldata rootWithVersion,
        uint64[] calldata sourceChainIds,
        uint[] calldata pledgeAmounts
    ) external payable;

    function updateRulesRootERC20(
        uint64 enableTime,
        address ebc,
        RuleLib.Rule[] calldata rules,
        RuleLib.RootWithVersion calldata rootWithVersion,
        uint64[] calldata sourceChainIds,
        uint[] calldata pledgeAmounts,
        address token
    ) external;

    function getCanChallengeFinish(uint64 challengeIdentNum) external view returns (bool);

    function challenge(
        uint64 sourceChainId,
        bytes32 sourceTxHash,
        uint64 sourceTxTime,
        address freezeToken,
        uint freezeAmount1,
        uint64 transactionIndex
    ) external payable;

    function checkChallenge(uint64 sourceChainId, bytes32 sourceTxHash, uint[] calldata verifiedData0) external;

    function verifyChallengeSource(
        address spvAddress,
        bytes calldata proof,
        bytes32[2] calldata spvBlockHashs,
        IORChallengeSpv.VerifyInfo calldata verifyInfo,
        bytes calldata rawDatas
    ) external;

    function verifyChallengeDest(
        address spvAddress,
        bytes calldata proof,
        bytes32[2] calldata spvBlockHashs,
        IORChallengeSpv.VerifyInfo calldata verifyInfo,
        uint[] calldata verifiedData0,
        bytes calldata rawDatas
    ) external;
}
