// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORChallengeSpv} from "./IORChallengeSpv.sol";
import {BridgeLib} from "../library/BridgeLib.sol";
import {RuleLib} from "../library/RuleLib.sol";

interface IORMakerDeposit {
    struct PublicInputData {
        bytes32 tx_hash;
        uint64 chain_id;
        uint256 index;
        uint256 from;
        uint160 to;
        address token;
        uint256 amount;
        uint256 nonce;
        uint256 time_stamp;
        uint160 dest;
        uint160 dest_token;
        bytes32 l1_tx_block_hash;
        uint256 l1_tx_block_number;
        address mdc_contract_address;
        address manager_contract_address;
        uint256 mdc_rule_root_slot;
        uint256 mdc_rule_version_slot;
        uint256 mdc_rule_enable_time_slot;
        bytes32 mdc_column_array_hash_slot;
        bytes32 mdc_response_makers_hash_slot;
        bytes32 manage_source_chain_info_slot;
        bytes32 manage_source_chain_mainnet_token_info_slot;
        bytes32 manage_dest_chain_mainnet_token_slot;
        bytes32 manage_challenge_user_ratio_slot;
        bytes32 mdc_pre_rule_root;
        uint256 mdc_pre_rule_version;
        uint256 mdc_pre_rule_enable_time;
        bytes32 mdc_pre_column_array_hash;
        uint256 mdc_pre_response_makers_hash;
        // uint64 manage_pre_source_chain_max_verify_challenge_source_tx_second;
        // uint64 manage_pre_source_chain_min_verify_challenge_source_tx_second;
        // uint64 manage_pre_source_chain_max_verify_challenge_dest_tx_second;
        // uint64 manage_pre_source_chain_min_verify_challenge_dest_tx_second;
        uint256 manage_pre_source_chain_info;
        address manage_pre_source_chain_mainnet_token;
        address manage_pre_dest_chain_mainnet_token;
        uint64 manage_pre_challenge_user_ratio;
        bytes32 mdc_current_rule_root;
        uint256 mdc_current_rule_version;
        uint256 mdc_current_rule_enable_time;
        uint256 source_chain_id;
        address source_token;
        uint256 source_min_price;
        uint256 source_max_price;
        uint256 source_with_holding_fee;
        uint256 source_trading_fee;
        uint256 source_response_time;
        uint256 dest_chain_id;
        uint256 dest_token_rule;
        uint256 dest_min_price;
        uint256 dest_max_price;
        uint256 dest_with_holding_fee;
        uint256 dest_trading_fee;
        uint256 dest_response_time;
        bytes32 ob_contracts_pre_block_hash;
        uint256 ob_contracts_pre_block_number;
        bytes32 ob_contracts_current_block_hash;
        uint256 ob_contracts_current_block_number;
    }

    struct PublicInputDataDest {
        bytes32 txHash;
        uint64 chainId;
        uint256 txIndex;
        uint256 from;
        uint256 to;
        uint256 token;
        uint256 amount;
        uint256 nonce;
        uint64 timestamp;
        bytes32 L1TXBlockHash;
        uint256 L1TBlockNumber;
    }

    struct ChallengeStatement {
        uint sourceTxFrom; // From of the source tx. Uint to support other networks
        uint64 sourceTxTime; // Timestamp of the source tx
        address freezeToken; // Freeze token on L1
        uint64 challengeUserRatio; // Manager's _challengeUserRatio
        uint freezeAmount0; // Owner's freeze amount
        uint freezeAmount1; // Challenger's freeze amount
        uint64 challengeTime; // Time of challenge
        uint64 abortTime; // Time of abort caused by checkChallenge
        uint64 sourceTxBlockNum;
        uint64 sourceTxIndex;
        uint128 challengerVerifyTransactionFee; // Transaction fee of challenger verify
    }

    struct ChallengeResult {
        address winner; //Challenger Address
        uint64 verifiedTime0; // Time of verifyChallengeSource. Greater than 0 means verification passed
        uint64 verifiedTime1; // Time of verifyChallengeDest. Greater than 0 means verification passed
        bytes32 verifiedDataHash0; // Data's hash of verifyChallengeSource
    }
    struct ChallengeInfo {
        mapping(address => ChallengeStatement) statement;
        ChallengeResult result;
    }

    struct ChallengeNode {
        uint256 prev;
        uint64 challengeCreateTime;
        bool challengeFinished;
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
    event ChallengeInfoUpdated(bytes32 indexed challengeId, ChallengeStatement statement, ChallengeResult result);

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

    function getCanChallengeContinue(uint256 challengeIdentNum) external view returns (bool);

    function challenge(
        uint64 sourceTxTime,
        uint64 sourceChainId,
        uint64 sourceTxBlockNum,
        uint64 sourceTxIndex,
        bytes32 sourceTxHash,
        address freezeToken,
        uint freezeAmount1,
        uint256 parentNodeNumOfTargetNode
    ) external payable;

    function checkChallenge(uint64 sourceChainId, bytes32 sourceTxHash, address[] calldata challenger) external;

    // function verifyChallengeSource(
    //     address spvAddress,
    //     address challenger,
    //     bytes calldata proof,
    //     IORChallengeSpv.VerifyInfo calldata verifyInfo,
    //     bytes calldata rawDatas
    // ) external;

    function verifyChallengeDest(
        address spvAddress,
        address challenger,
        uint64 sourceChainId,
        bytes32 sourceTxHash,
        bytes calldata proof,
        uint[] calldata verifiedData0,
        bytes calldata rawDatas
    ) external;

    // function verifyChallengeSource(
    //     address spvAddress,
    //     address challenger,
    //     bytes calldata proof,
    //     bytes32[2] calldata spvBlockHashs,
    //     IORChallengeSpv.VerifyInfo calldata verifyInfo,
    //     bytes calldata rawDatas
    // ) external;

    // function verifyChallengeDest(
    //     address spvAddress,
    //     address challenger,
    //     bytes calldata proof,
    //     bytes32[2] calldata spvBlockHashs,
    //     IORChallengeSpv.VerifyInfo calldata verifyInfo,
    //     uint[] calldata verifiedData0,
    //     bytes calldata rawDatas,
    //     uint64 sourceChainId
    // ) external;
}
