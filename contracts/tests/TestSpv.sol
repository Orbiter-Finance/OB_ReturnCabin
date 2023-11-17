// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {RuleLib} from "../library/RuleLib.sol";
import {HelperLib} from "../library/HelperLib.sol";
import {IVerifierRouter} from "../zkp/IVerifierRouter.sol";
import {IOREventBinding} from "../interface/IOREventBinding.sol";

contract testSpv {
    using HelperLib for bytes;
    address public v_address;
    address public ebc_address;

    constructor(address verifier, address ebc) {
        v_address = verifier;
        ebc_address = ebc;
    }

    function set_v(address _v) public {
        v_address = _v;
    }

    struct PublicInputData {
        bytes32 tx_hash;
        uint256 chain_id;
        uint256 index;
        address from;
        address to;
        address token;
        uint256 amount;
        uint256 nonce;
        uint256 time_stamp;
        address dest;
        address dest_token;
        bytes32 l1_tx_block_hash;
        uint256 l1_tx_block_number;
        address mdc_contract_address;
        address manage_contract_address;
        bytes32 mdc_rule_root_slot;
        bytes32 mdc_rule_version_slot;
        bytes32 mdc_rule_enable_time_slot;
        bytes32 mdc_column_array_hash_slot;
        bytes32 mdc_response_makers_hash_slot;
        bytes32 manage_source_chain_info_slot;
        bytes32 manage_source_chain_mainnet_token_info_slot;
        bytes32 manage_dest_chain_mainnet_token_slot;
        bytes32 manage_challenge_user_ratio_slot;
        bytes32 mdc_current_rule_root;
        uint256 mdc_current_rule_enable_time;
        bytes32 mdc_current_column_array_hash;
        bytes32 mdc_current_response_makers_hash;
        uint64 min_verify_challenge_src_tx_second;
        uint64 max_verify_challenge_src_tx_second;
        uint64 min_verify_challenge_dest_tx_second;
        uint64 max_verify_challenge_dest_tx_second;
        address manage_current_source_chain_mainnet_token;
        address manage_current_dest_chain_mainnet_token;
        uint256 manage_current_challenge_user_ratio;
        uint256 mdc_next_rule_enable_time;
        bytes32 mdc_current_rule_value_hash;
    }

    function parsePublicInput(bytes calldata proofData) external pure returns (PublicInputData memory) {
        uint256 ProofLength = 384;
        uint256 SplitStep = 32;
        uint256 TransactionSplitStart = ProofLength + 64; // 384 is proof length;64 is blockHash length
        uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 12;
        uint256 MdcContractSplitStart = TrackBlockSplitStart + SplitStep * 9;

        return
            PublicInputData({
                tx_hash: bytes32(
                    (uint256(bytes32(proofData[TransactionSplitStart:TransactionSplitStart + SplitStep])) << 128) |
                        uint256(
                            bytes32(proofData[TransactionSplitStart + SplitStep:TransactionSplitStart + SplitStep * 2])
                        )
                ),
                chain_id: uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 2:TransactionSplitStart + SplitStep * 3])
                ),
                index: uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 3:TransactionSplitStart + SplitStep * 4])
                ),
                from: address(
                    uint160(
                        uint256(
                            bytes32(
                                proofData[TransactionSplitStart + SplitStep * 4:TransactionSplitStart + SplitStep * 5]
                            )
                        )
                    )
                ),
                to: address(
                    uint160(
                        uint256(
                            bytes32(
                                proofData[TransactionSplitStart + SplitStep * 5:TransactionSplitStart + SplitStep * 6]
                            )
                        )
                    )
                ),
                token: address(
                    uint160(
                        uint256(
                            bytes32(
                                proofData[TransactionSplitStart + SplitStep * 6:TransactionSplitStart + SplitStep * 7]
                            )
                        )
                    )
                ),
                amount: uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 7:TransactionSplitStart + SplitStep * 8])
                ),
                nonce: uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 8:TransactionSplitStart + SplitStep * 9])
                ),
                time_stamp: uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 9:TransactionSplitStart + SplitStep * 10])
                ),
                dest: address(
                    uint160(
                        uint256(
                            bytes32(
                                proofData[TransactionSplitStart + SplitStep * 10:TransactionSplitStart + SplitStep * 11]
                            )
                        )
                    )
                ),
                dest_token: address(
                    uint160(
                        uint256(
                            bytes32(
                                proofData[TransactionSplitStart + SplitStep * 11:TransactionSplitStart + SplitStep * 12]
                            )
                        )
                    )
                ),
                l1_tx_block_hash: bytes32(
                    (uint256(bytes32(proofData[TrackBlockSplitStart:TrackBlockSplitStart + SplitStep])) << 128) |
                        uint256(
                            bytes32(proofData[TrackBlockSplitStart + SplitStep:TrackBlockSplitStart + SplitStep * 2])
                        )
                ),
                l1_tx_block_number: uint256(
                    bytes32(proofData[TrackBlockSplitStart + SplitStep * 2:TrackBlockSplitStart + SplitStep * 3])
                ),
                mdc_contract_address: address(
                    uint160(uint256(bytes32(proofData[MdcContractSplitStart:MdcContractSplitStart + SplitStep])))
                ),
                manage_contract_address: address(
                    uint160(
                        uint256(
                            bytes32(proofData[MdcContractSplitStart + SplitStep:MdcContractSplitStart + SplitStep * 2])
                        )
                    )
                ),
                mdc_rule_root_slot: bytes32(
                    (uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 2:MdcContractSplitStart + SplitStep * 3])
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 3:MdcContractSplitStart + SplitStep * 4]
                            )
                        )
                ),
                mdc_rule_version_slot: bytes32(
                    (uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 4:MdcContractSplitStart + SplitStep * 5])
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 5:MdcContractSplitStart + SplitStep * 6]
                            )
                        )
                ),
                mdc_rule_enable_time_slot: bytes32(
                    (uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 6:MdcContractSplitStart + SplitStep * 7])
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 7:MdcContractSplitStart + SplitStep * 8]
                            )
                        )
                ),
                mdc_column_array_hash_slot: bytes32(
                    (uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 8:MdcContractSplitStart + SplitStep * 9])
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 9:MdcContractSplitStart + SplitStep * 10]
                            )
                        )
                ),
                mdc_response_makers_hash_slot: bytes32(
                    (uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 10:MdcContractSplitStart + SplitStep * 11]
                        )
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 11:MdcContractSplitStart + SplitStep * 12]
                            )
                        )
                ),
                manage_source_chain_info_slot: bytes32(
                    (uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 12:MdcContractSplitStart + SplitStep * 13]
                        )
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 13:MdcContractSplitStart + SplitStep * 14]
                            )
                        )
                ),
                manage_source_chain_mainnet_token_info_slot: bytes32(
                    (uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 14:MdcContractSplitStart + SplitStep * 15]
                        )
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 15:MdcContractSplitStart + SplitStep * 16]
                            )
                        )
                ),
                manage_dest_chain_mainnet_token_slot: bytes32(
                    (uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 16:MdcContractSplitStart + SplitStep * 17]
                        )
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 17:MdcContractSplitStart + SplitStep * 18]
                            )
                        )
                ),
                manage_challenge_user_ratio_slot: bytes32(
                    (uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 18:MdcContractSplitStart + SplitStep * 19]
                        )
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 19:MdcContractSplitStart + SplitStep * 20]
                            )
                        )
                ),
                mdc_current_rule_root: bytes32(
                    (uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 20:MdcContractSplitStart + SplitStep * 21]
                        )
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 21:MdcContractSplitStart + SplitStep * 22]
                            )
                        )
                ),
                mdc_current_rule_enable_time: uint64(
                    bytes8(
                        proofData[MdcContractSplitStart + SplitStep * 22 + SplitStep / 2:MdcContractSplitStart +
                            SplitStep *
                            22 +
                            SplitStep /
                            2 +
                            SplitStep /
                            4]
                    )
                ),
                mdc_current_column_array_hash: bytes32(
                    (uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 24:MdcContractSplitStart + SplitStep * 25]
                        )
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 25:MdcContractSplitStart + SplitStep * 26]
                            )
                        )
                ),
                mdc_current_response_makers_hash: bytes32(
                    (uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 26:MdcContractSplitStart + SplitStep * 27]
                        )
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 27:MdcContractSplitStart + SplitStep * 28]
                            )
                        )
                ),
                max_verify_challenge_src_tx_second: uint64(
                    bytes8(
                        proofData[MdcContractSplitStart + SplitStep * 29 + SplitStep / 2:MdcContractSplitStart +
                            SplitStep *
                            29 +
                            SplitStep /
                            2 +
                            SplitStep /
                            4]
                    )
                ),
                min_verify_challenge_src_tx_second: uint64(
                    bytes8(
                        proofData[MdcContractSplitStart +
                            SplitStep *
                            29 +
                            SplitStep /
                            2 +
                            SplitStep /
                            4:MdcContractSplitStart + SplitStep * 29 + SplitStep / 2 + SplitStep / 4 + SplitStep / 4]
                    )
                ),
                max_verify_challenge_dest_tx_second: uint64(
                    bytes8(
                        proofData[MdcContractSplitStart + SplitStep * 28 + SplitStep / 2:MdcContractSplitStart +
                            SplitStep *
                            28 +
                            SplitStep /
                            2 +
                            SplitStep /
                            4]
                    )
                ),
                min_verify_challenge_dest_tx_second: uint64(
                    bytes8(
                        proofData[MdcContractSplitStart +
                            SplitStep *
                            28 +
                            SplitStep /
                            2 +
                            SplitStep /
                            4:MdcContractSplitStart + SplitStep * 28 + SplitStep / 2 + SplitStep / 4 + SplitStep / 4]
                    )
                ),
                manage_current_source_chain_mainnet_token: address(
                    uint160(
                        uint256(
                            bytes32(
                                (uint256(
                                    bytes32(
                                        proofData[MdcContractSplitStart + SplitStep * 30:MdcContractSplitStart +
                                            SplitStep *
                                            31]
                                    )
                                ) << 128) |
                                    uint256(
                                        bytes32(
                                            proofData[MdcContractSplitStart + SplitStep * 31:MdcContractSplitStart +
                                                SplitStep *
                                                32]
                                        )
                                    )
                            )
                        )
                    )
                ),
                manage_current_dest_chain_mainnet_token: address(
                    uint160(
                        uint256(
                            bytes32(
                                (uint256(
                                    bytes32(
                                        proofData[MdcContractSplitStart + SplitStep * 32:MdcContractSplitStart +
                                            SplitStep *
                                            33]
                                    )
                                ) << 128) |
                                    uint256(
                                        bytes32(
                                            proofData[MdcContractSplitStart + SplitStep * 33:MdcContractSplitStart +
                                                SplitStep *
                                                34]
                                        )
                                    )
                            )
                        )
                    )
                ),
                manage_current_challenge_user_ratio: uint64(
                    bytes8(
                        proofData[MdcContractSplitStart + SplitStep * 35 + SplitStep / 2:MdcContractSplitStart +
                            SplitStep *
                            35 +
                            SplitStep /
                            2 +
                            SplitStep /
                            4]
                    )
                ),
                mdc_next_rule_enable_time: uint64(
                    bytes8(
                        proofData[MdcContractSplitStart + SplitStep * 36 + SplitStep / 2:MdcContractSplitStart +
                            SplitStep *
                            36 +
                            SplitStep /
                            2 +
                            SplitStep /
                            4]
                    )
                ),
                mdc_current_rule_value_hash: bytes32(
                    (uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 38:MdcContractSplitStart + SplitStep * 39]
                        )
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 39:MdcContractSplitStart + SplitStep * 40]
                            )
                        )
                )
            });
    }

    // struct PublicInputData {
    //     bytes32 tx_hash;
    //     uint64 chain_id;
    //     uint256 index;
    //     uint256 from;
    //     uint160 to;
    //     address token;
    //     uint256 amount;
    //     uint256 nonce;
    //     uint256 time_stamp;
    //     uint160 dest;
    //     uint160 dest_token;
    //     bytes32 l1_tx_block_hash;
    //     uint256 l1_tx_block_number;
    //     address mdc_contract_address;
    //     address manager_contract_address;
    //     uint256 mdc_rule_root_slot;
    //     uint256 mdc_rule_version_slot;
    //     uint256 mdc_rule_enable_time_slot;
    //     bytes32 mdc_column_array_hash_slot;
    //     bytes32 mdc_response_makers_hash_slot;
    //     bytes32 manage_source_chain_info_slot;
    //     bytes32 manage_source_chain_mainnet_token_info_slot;
    //     bytes32 manage_dest_chain_mainnet_token_slot;
    //     bytes32 manage_challenge_user_ratio_slot;
    //     bytes32 mdc_pre_rule_root;
    //     uint256 mdc_pre_rule_version;
    //     uint256 mdc_pre_rule_enable_time;
    //     bytes32 mdc_pre_column_array_hash;
    //     bytes32 mdc_pre_response_makers_hash;
    //     // bytes32 manage_pre_source_chain_info;
    //     uint64 manage_pre_source_chain_max_verify_challenge_source_tx_second;
    //     uint64 manage_pre_source_chain_min_verify_challenge_source_tx_second;
    //     uint64 manage_pre_source_chain_max_verify_challenge_dest_tx_second;
    //     uint64 manage_pre_source_chain_min_verify_challenge_dest_tx_second;
    //     address manage_pre_source_chain_mainnet_token;
    //     address manage_pre_dest_chain_mainnet_token;
    //     uint64 manage_pre_challenge_user_ratio;
    //     bytes32 mdc_current_rule_root;
    //     uint256 mdc_current_rule_version;
    //     uint256 mdc_current_rule_enable_time;
    //     uint256 source_chain_id;
    //     address source_token;
    //     uint256 source_min_price;
    //     uint256 source_max_price;
    //     uint256 source_with_holding_fee;
    //     uint256 source_trading_fee;
    //     uint256 source_response_time;
    //     uint256 dest_chain_id;
    //     address dest_token_rule;
    //     uint256 dest_min_price;
    //     uint256 dest_max_price;
    //     uint256 dest_with_holding_fee;
    //     uint256 dest_trading_fee;
    //     uint256 dest_response_time;
    //     bytes32 ob_contracts_pre_block_hash;
    //     uint256 ob_contracts_pre_block_number;
    //     bytes32 ob_contracts_current_block_hash;
    //     uint256 ob_contracts_current_block_number;
    // }

    // function parsePublicInput(bytes calldata proofData) external pure returns (PublicInputData memory) {
    //     uint256 ProofLength = 384;
    //     uint256 SplitStep = 32;
    //     uint256 TransactionSplitStart = ProofLength + 64; //  448  384 is proof length;64 is blockHash length
    //     uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 12;  // 832
    //     uint256 MdcContractSplitStart = TrackBlockSplitStart + SplitStep * 9;   // 1120
    //     uint256 EbcConfigSplitStart = MdcContractSplitStart+SplitStep*44;       // 2528
    //     // uint256 instanceBytesLength = EbcConfigSplitStart+SplitStep*14;

    //     return
    //         PublicInputData({
    //             tx_hash: bytes32(
    //                 (uint256(bytes32(proofData[TransactionSplitStart:TransactionSplitStart + SplitStep])) << 128) |
    //                     uint256(
    //                         bytes32(proofData[TransactionSplitStart + SplitStep:TransactionSplitStart + SplitStep * 2])
    //                     )
    //             ),
    //             chain_id: uint64(
    //                 uint256(
    //                     bytes32(proofData[TransactionSplitStart + SplitStep * 2:TransactionSplitStart + SplitStep * 3])
    //                 )
    //             ),
    //             index: uint256(
    //                 bytes32(proofData[TransactionSplitStart + SplitStep * 3:TransactionSplitStart + SplitStep * 4])
    //             ),
    //             from: (
    //                 (
    //                     uint256(
    //                         bytes32(
    //                             proofData[TransactionSplitStart + SplitStep * 4:TransactionSplitStart + SplitStep * 5]
    //                         )
    //                     )
    //                 )
    //             ),
    //             to: (
    //                 uint160(
    //                     uint256(
    //                         bytes32(
    //                             proofData[TransactionSplitStart + SplitStep * 5:TransactionSplitStart + SplitStep * 6]
    //                         )
    //                     )
    //                 )
    //             ),
    //             token: address(
    //                 uint160(
    //                     uint256(
    //                         bytes32(
    //                             proofData[TransactionSplitStart + SplitStep * 6:TransactionSplitStart + SplitStep * 7]
    //                         )
    //                     )
    //                 )
    //             ),
    //             amount: uint256(
    //                 bytes32(proofData[TransactionSplitStart + SplitStep * 7:TransactionSplitStart + SplitStep * 8])
    //             ),
    //             nonce: uint256(
    //                 bytes32(proofData[TransactionSplitStart + SplitStep * 8:TransactionSplitStart + SplitStep * 9])
    //             ),
    //             time_stamp: uint256(
    //                 bytes32(proofData[TransactionSplitStart + SplitStep * 9:TransactionSplitStart + SplitStep * 10])
    //             ),
    //             dest: (
    //                 uint160(
    //                     uint256(
    //                         bytes32(
    //                             proofData[TransactionSplitStart + SplitStep * 10:TransactionSplitStart + SplitStep * 11]
    //                         )
    //                     )
    //                 )
    //             ),
    //             dest_token: (
    //                 uint160(
    //                     uint256(
    //                         bytes32(
    //                             proofData[TransactionSplitStart + SplitStep * 11:TransactionSplitStart + SplitStep * 12]
    //                         )
    //                     )
    //                 )
    //             ),
    //             l1_tx_block_hash: bytes32(
    //                 (uint256(bytes32(proofData[TrackBlockSplitStart:TrackBlockSplitStart + SplitStep])) << 128) |
    //                     uint256(
    //                         bytes32(proofData[TrackBlockSplitStart + SplitStep:TrackBlockSplitStart + SplitStep * 2])
    //                     )
    //             ),
    //             l1_tx_block_number: uint256(
    //                 bytes32(proofData[TrackBlockSplitStart + SplitStep * 2:TrackBlockSplitStart + SplitStep * 3])
    //             ),
    //             mdc_contract_address: address(
    //                 uint160(uint256(bytes32(proofData[MdcContractSplitStart:MdcContractSplitStart + SplitStep])))
    //             ),
    //             manager_contract_address: address(
    //                 uint160(
    //                     uint256(
    //                         bytes32(proofData[MdcContractSplitStart + SplitStep:MdcContractSplitStart + SplitStep * 2])
    //                     )
    //                 )
    //             ),
    //             mdc_rule_root_slot: ((uint256(
    //                 bytes32(proofData[MdcContractSplitStart + SplitStep * 2:MdcContractSplitStart + SplitStep * 3])
    //             ) << 128) |
    //                 uint256(
    //                     bytes32(proofData[MdcContractSplitStart + SplitStep * 3:MdcContractSplitStart + SplitStep * 4])
    //                 )),
    //             mdc_rule_version_slot: ((uint256(
    //                 bytes32(proofData[MdcContractSplitStart + SplitStep * 4:MdcContractSplitStart + SplitStep * 5])
    //             ) << 128) |
    //                 uint256(
    //                     bytes32(proofData[MdcContractSplitStart + SplitStep * 5:MdcContractSplitStart + SplitStep * 6])
    //                 )),
    //             mdc_rule_enable_time_slot: ((uint256(
    //                 bytes32(proofData[MdcContractSplitStart + SplitStep * 6:MdcContractSplitStart + SplitStep * 7])
    //             ) << 128) |
    //                 uint256(
    //                     bytes32(proofData[MdcContractSplitStart + SplitStep * 7:MdcContractSplitStart + SplitStep * 8])
    //                 )),
    //             mdc_column_array_hash_slot: bytes32(
    //                 (uint256(
    //                     bytes32(proofData[MdcContractSplitStart + SplitStep * 8:MdcContractSplitStart + SplitStep * 9])
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 9:MdcContractSplitStart + SplitStep * 10]
    //                         )
    //                     )
    //             ),
    //             mdc_response_makers_hash_slot: bytes32(
    //                 (uint256(
    //                     bytes32(
    //                         proofData[MdcContractSplitStart + SplitStep * 10:MdcContractSplitStart + SplitStep * 11]
    //                     )
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 11:MdcContractSplitStart + SplitStep * 12]
    //                         )
    //                     )
    //             ),
    //             manage_source_chain_info_slot: bytes32(
    //                 (uint256(
    //                     bytes32(
    //                         proofData[MdcContractSplitStart + SplitStep * 12:MdcContractSplitStart + SplitStep * 13]
    //                     )
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 13:MdcContractSplitStart + SplitStep * 14]
    //                         )
    //                     )
    //             ),
    //             manage_source_chain_mainnet_token_info_slot: bytes32(
    //                 (uint256(
    //                     bytes32(
    //                         proofData[MdcContractSplitStart + SplitStep * 14:MdcContractSplitStart + SplitStep * 15]
    //                     )
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 15:MdcContractSplitStart + SplitStep * 16]
    //                         )
    //                     )
    //             ),
    //             manage_dest_chain_mainnet_token_slot: bytes32(
    //                 (uint256(
    //                     bytes32(
    //                         proofData[MdcContractSplitStart + SplitStep * 16:MdcContractSplitStart + SplitStep * 17]
    //                     )
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 17:MdcContractSplitStart + SplitStep * 18]
    //                         )
    //                     )
    //             ),
    //             manage_challenge_user_ratio_slot: bytes32(
    //                 (uint256(
    //                     bytes32(
    //                         proofData[MdcContractSplitStart + SplitStep * 18:MdcContractSplitStart + SplitStep * 19]
    //                     )
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 19:MdcContractSplitStart + SplitStep * 20]
    //                         )
    //                     )
    //             ),
    //             mdc_pre_rule_root: bytes32(
    //                 (uint256(
    //                     bytes32(
    //                         proofData[MdcContractSplitStart + SplitStep * 20:MdcContractSplitStart + SplitStep * 21]
    //                     )
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 21:MdcContractSplitStart + SplitStep * 22]
    //                         )
    //                     )
    //             ),
    //             mdc_pre_rule_version: uint256(
    //                 bytes32(
    //                     (uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 22:MdcContractSplitStart + SplitStep * 23]
    //                         )
    //                     ) << 128) |
    //                         uint256(
    //                             bytes32(
    //                                 proofData[MdcContractSplitStart + SplitStep * 23:MdcContractSplitStart +
    //                                     SplitStep *
    //                                     24]
    //                             )
    //                         )
    //                 )
    //             ),
    //             mdc_pre_rule_enable_time: uint64(
    //                 bytes8(
    //                     proofData[MdcContractSplitStart + SplitStep * 24 + SplitStep / 2:MdcContractSplitStart +
    //                         SplitStep *
    //                         24 +
    //                         SplitStep /
    //                         2 +
    //                         SplitStep /
    //                         4]
    //                 )
    //             ),
    //             mdc_pre_column_array_hash: bytes32(
    //                 (uint256(
    //                     bytes32(
    //                         proofData[MdcContractSplitStart + SplitStep * 26:MdcContractSplitStart + SplitStep * 27]
    //                     )
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 27:MdcContractSplitStart + SplitStep * 28]
    //                         )
    //                     )
    //             ),
    //             mdc_pre_response_makers_hash: bytes32(
    //                 (uint256(
    //                     bytes32(
    //                         proofData[MdcContractSplitStart + SplitStep * 28:MdcContractSplitStart + SplitStep * 29]
    //                     )
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 29:MdcContractSplitStart + SplitStep * 30]
    //                         )
    //                     )
    //             ),
    //             manage_pre_source_chain_info: bytes32(
    //                 (uint256(
    //                     bytes32(
    //                         proofData[MdcContractSplitStart + SplitStep * 30:MdcContractSplitStart + SplitStep * 31]
    //                     )
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 31:MdcContractSplitStart + SplitStep * 32]
    //                         )
    //                     )
    //             ),
    //             manage_pre_source_chain_mainnet_token: address(
    //                 uint160(
    //                     uint256(
    //                         bytes32(
    //                             (uint256(
    //                                 bytes32(
    //                                     proofData[MdcContractSplitStart + SplitStep * 32:MdcContractSplitStart +
    //                                         SplitStep *
    //                                         33]
    //                                 )
    //                             ) << 128) |
    //                                 uint256(
    //                                     bytes32(
    //                                         proofData[MdcContractSplitStart + SplitStep * 33:MdcContractSplitStart +
    //                                             SplitStep *
    //                                             34]
    //                                     )
    //                                 )
    //                         )
    //                     )
    //                 )
    //             ),
    //             manage_pre_dest_chain_mainnet_token: address(
    //                 uint160(
    //                     uint256(
    //                         bytes32(
    //                             (uint256(
    //                                 bytes32(
    //                                     proofData[MdcContractSplitStart + SplitStep * 34:MdcContractSplitStart +
    //                                         SplitStep *
    //                                         35]
    //                                 )
    //                             ) << 128) |
    //                                 uint256(
    //                                     bytes32(
    //                                         proofData[MdcContractSplitStart + SplitStep * 35:MdcContractSplitStart +
    //                                             SplitStep *
    //                                             36]
    //                                     )
    //                                 )
    //                         )
    //                     )
    //                 )
    //             ),
    //             manage_pre_challenge_user_ratio: uint64(
    //                 bytes8(
    //                     proofData[MdcContractSplitStart + SplitStep * 37 + SplitStep / 2:MdcContractSplitStart +
    //                         SplitStep *
    //                         37 +
    //                         SplitStep /
    //                         2 +
    //                         SplitStep /
    //                         4]
    //                 )
    //             ),
    //             mdc_current_rule_root: bytes32(
    //                 (uint256(
    //                     bytes32(
    //                         proofData[MdcContractSplitStart + SplitStep * 38:MdcContractSplitStart + SplitStep * 39]
    //                     )
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 39:MdcContractSplitStart + SplitStep * 40]
    //                         )
    //                     )
    //             ),
    //             mdc_current_rule_version: uint256(
    //                 bytes32(
    //                     (uint256(
    //                         bytes32(
    //                             proofData[MdcContractSplitStart + SplitStep * 40:MdcContractSplitStart + SplitStep * 41]
    //                         )
    //                     ) << 128) |
    //                         uint256(
    //                             bytes32(
    //                                 proofData[MdcContractSplitStart + SplitStep * 41:MdcContractSplitStart +
    //                                     SplitStep *
    //                                     42]
    //                             )
    //                         )
    //                 )
    //             ),
    //             mdc_current_rule_enable_time: uint64(
    //                 bytes8(
    //                     proofData[MdcContractSplitStart + SplitStep * 42 + SplitStep / 2:MdcContractSplitStart +
    //                         SplitStep *
    //                         42 +
    //                         SplitStep /
    //                         2 +
    //                         SplitStep /
    //                         4]
    //                 )
    //             ),
    //             source_chain_id: uint256(bytes32(proofData[EbcConfigSplitStart:EbcConfigSplitStart + SplitStep])),
    //             source_token: address(
    //                 uint160(
    //                     uint256(bytes32(proofData[EbcConfigSplitStart + SplitStep:EbcConfigSplitStart + SplitStep * 2]))
    //                 )
    //             ),
    //             source_min_price: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 2:EbcConfigSplitStart + SplitStep * 3])
    //             ),
    //             source_max_price: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 3:EbcConfigSplitStart + SplitStep * 4])
    //             ),
    //             source_with_holding_fee: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 4:EbcConfigSplitStart + SplitStep * 5])
    //             ),
    //             source_trading_fee: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 5:EbcConfigSplitStart + SplitStep * 6])
    //             ),
    //             source_response_time: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 6:EbcConfigSplitStart + SplitStep * 7])
    //             ),
    //             dest_chain_id: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 7:EbcConfigSplitStart + SplitStep * 8])
    //             ),
    //             dest_token_rule: address(
    //                 uint160(
    //                     uint256(
    //                         bytes32(proofData[EbcConfigSplitStart + SplitStep * 8:EbcConfigSplitStart + SplitStep * 9])
    //                     )
    //                 )
    //             ),
    //             dest_min_price: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 9:EbcConfigSplitStart + SplitStep * 10])
    //             ),
    //             dest_max_price: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 10:EbcConfigSplitStart + SplitStep * 11])
    //             ),
    //             dest_with_holding_fee: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 11:EbcConfigSplitStart + SplitStep * 12])
    //             ),
    //             dest_trading_fee: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 12:EbcConfigSplitStart + SplitStep * 13])
    //             ),
    //             dest_response_time: uint256(
    //                 bytes32(proofData[EbcConfigSplitStart + SplitStep * 13:EbcConfigSplitStart + SplitStep * 14])
    //             ),
    //             ob_contracts_pre_block_hash: bytes32(
    //                 (uint256(
    //                     bytes32(proofData[TrackBlockSplitStart + SplitStep * 3:TrackBlockSplitStart + SplitStep * 4])
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[TrackBlockSplitStart + SplitStep * 4:TrackBlockSplitStart + SplitStep * 5]
    //                         )
    //                     )
    //             ),
    //             ob_contracts_pre_block_number: uint256(
    //                 bytes32(proofData[TrackBlockSplitStart + SplitStep * 5:TrackBlockSplitStart + SplitStep * 6])
    //             ),
    //             ob_contracts_current_block_hash: bytes32(
    //                 (uint256(
    //                     bytes32(proofData[TrackBlockSplitStart + SplitStep * 6:TrackBlockSplitStart + SplitStep * 7])
    //                 ) << 128) |
    //                     uint256(
    //                         bytes32(
    //                             proofData[TrackBlockSplitStart + SplitStep * 7:TrackBlockSplitStart + SplitStep * 8]
    //                         )
    //                     )
    //             ),
    //             ob_contracts_current_block_number: uint256(
    //                 bytes32(proofData[TrackBlockSplitStart + SplitStep * 8:TrackBlockSplitStart + SplitStep * 9])
    //             )
    //         });
    // }

    // function parsePublicInputNew(bytes calldata proofData) external pure returns (PublicInputData memory) {
    //     return
    //         PublicInputData({
    //             tx_hash: bytes32((uint256(bytes32(proofData[448:480])) << 128) | uint256(bytes32(proofData[480:512]))),
    //             chain_id: uint64(uint256(bytes32(proofData[512:544]))),
    //             index: uint256(bytes32(proofData[544:576])),
    //             from: uint256(bytes32(proofData[576:608])),
    //             to: uint160(uint256(bytes32(proofData[608:640]))),
    //             token: address(uint160(uint256(bytes32(proofData[640:672])))),
    //             amount: uint256(bytes32(proofData[672:704])),
    //             nonce: uint256(bytes32(proofData[704:736])),
    //             time_stamp: uint256(bytes32(proofData[736:768])),
    //             dest: uint160(uint256(bytes32(proofData[768:800]))),
    //             dest_token: uint160(uint256(bytes32(proofData[800:832]))),
    //             l1_tx_block_hash: bytes32(
    //                 (uint256(bytes32(proofData[384:416])) << 128) | uint256(bytes32(proofData[416:448]))
    //             ),
    //             l1_tx_block_number: uint256(bytes32(proofData[896:928])),
    //             mdc_contract_address: address(uint160(uint256(bytes32(proofData[1120:1152])))),
    //             manager_contract_address: address(uint160(uint256(bytes32(proofData[1152:1184])))),
    //             mdc_rule_root_slot: (uint256(bytes32(proofData[1184:1216])) << 128) |
    //                 uint256(bytes32(proofData[1216:1248])),
    //             mdc_rule_version_slot: (uint256(bytes32(proofData[1248:1280])) << 128) |
    //                 uint256(bytes32(proofData[1280:1312])),
    //             mdc_rule_enable_time_slot: (uint256(bytes32(proofData[1312:1344])) << 128) |
    //                 uint256(bytes32(proofData[1344:1376])),
    //             mdc_column_array_hash_slot: bytes32(
    //                 (uint256(bytes32(proofData[1376:1408])) << 128) | uint256(bytes32(proofData[1408:1440]))
    //             ),
    //             mdc_response_makers_hash_slot: bytes32(
    //                 (uint256(bytes32(proofData[1440:1472])) << 128) | uint256(bytes32(proofData[1472:1504]))
    //             ),
    //             manage_source_chain_info_slot: bytes32(
    //                 (uint256(bytes32(proofData[1504:1536])) << 128) | uint256(bytes32(proofData[1536:1568]))
    //             ),
    //             manage_source_chain_mainnet_token_info_slot: bytes32(
    //                 (uint256(bytes32(proofData[1568:1600])) << 128) | uint256(bytes32(proofData[1600:1632]))
    //             ),
    //             manage_dest_chain_mainnet_token_slot: bytes32(
    //                 (uint256(bytes32(proofData[1632:1664])) << 128) | uint256(bytes32(proofData[1664:1696]))
    //             ),
    //             manage_challenge_user_ratio_slot: bytes32(
    //                 (uint256(bytes32(proofData[1696:1728])) << 128) | uint256(bytes32(proofData[1728:1760]))
    //             ),
    //             mdc_pre_rule_root: bytes32(
    //                 (uint256(bytes32(proofData[1760:1792])) << 128) | uint256(bytes32(proofData[1792:1824]))
    //             ),
    //             mdc_pre_rule_version: uint256(bytes32(proofData[1824:1856]) << 128) |
    //                 uint256(bytes32(proofData[1856:1888])),
    //             mdc_pre_rule_enable_time: uint64(bytes8(proofData[1904:1912])),
    //             mdc_pre_column_array_hash: bytes32(
    //                 (uint256(bytes32(proofData[1952:1984])) << 128) | uint256(bytes32(proofData[1984:2016]))
    //             ),
    //             mdc_pre_response_makers_hash: bytes32(
    //                 (uint256(bytes32(proofData[2016:2048])) << 128) | uint256(bytes32(proofData[2048:2080]))
    //             ),
    //             // manage_pre_source_chain_info: bytes32(
    //             //     (uint256(bytes32(proofData[2080:2112])) << 128) | uint256(bytes32(proofData[2112:2144]))
    //             // ),
    //             manage_pre_source_chain_max_verify_challenge_source_tx_second: uint64(bytes8(proofData[2128:2136])),
    //             manage_pre_source_chain_min_verify_challenge_source_tx_second: uint64(bytes8(proofData[2136:2144])),
    //             manage_pre_source_chain_max_verify_challenge_dest_tx_second: uint64(bytes8(proofData[2096:2104])),
    //             manage_pre_source_chain_min_verify_challenge_dest_tx_second: uint64(bytes8(proofData[2104:2112])),
    //             manage_pre_source_chain_mainnet_token: address(
    //                 uint160(uint256(bytes32(proofData[2144:2176]) << 128) | uint256(bytes32(proofData[2176:2208])))
    //             ),
    //             manage_pre_dest_chain_mainnet_token: address(
    //                 uint160(uint256(bytes32(proofData[2208:2240]) << 128) | uint256(bytes32(proofData[2240:2272])))
    //             ),
    //             manage_pre_challenge_user_ratio: uint64(bytes8(proofData[2320:2328])),
    //             mdc_current_rule_root: bytes32(
    //                 (uint256(bytes32(proofData[2336:2368])) << 128) | uint256(bytes32(proofData[2368:2400]))
    //             ),
    //             mdc_current_rule_version: uint256(bytes32(proofData[2400:2432]) << 128) |
    //                 uint256(bytes32(proofData[2432:2464])),
    //             mdc_current_rule_enable_time: uint64(bytes8(proofData[2480:2488]))
    //             // source_chain_id: uint256(bytes32(proofData[2528:2560])),
    //             // source_token: address(uint160(uint256(bytes32(proofData[2560:2592])))),
    //             // source_min_price: uint256(bytes32(proofData[2592:2624])),
    //             // source_max_price: uint256(bytes32(proofData[2624:2656])),
    //             // source_with_holding_fee: uint256(bytes32(proofData[2656:2688])),
    //             // source_trading_fee: uint256(bytes32(proofData[2688:2720])),
    //             // source_response_time: uint256(bytes32(proofData[2720:2752])),
    //             // dest_chain_id: uint256(bytes32(proofData[2752:2784])),
    //             // dest_token_rule: address(uint160(uint256(bytes32(proofData[2784:2816])))),
    //             // dest_min_price: uint256(bytes32(proofData[2816:2848])),
    //             // dest_max_price: uint256(bytes32(proofData[2848:2880])),
    //             // dest_with_holding_fee: uint256(bytes32(proofData[2880:2912])),
    //             // dest_trading_fee: uint256(bytes32(proofData[2912:2944])),
    //             // dest_response_time: uint256(bytes32(proofData[2944:2976])),
    //             // ob_contracts_pre_block_hash: bytes32(
    //             //     (uint256(bytes32(proofData[928:960])) << 128) | uint256(bytes32(proofData[960:992]))
    //             // ),
    //             // ob_contracts_pre_block_number: uint256(bytes32(proofData[992:1024])),
    //             // ob_contracts_current_block_hash: bytes32(
    //             //     (uint256(bytes32(proofData[1024:1056])) << 128) | uint256(bytes32(proofData[1056:1088]))
    //             // ),
    //             // ob_contracts_current_block_number: uint256(bytes32(proofData[1088:1120]))
    //         });
    // }

    // struct PublicInputData {
    //     uint64 sourceChainId;
    //     bytes32 sourceTxHash;
    //     uint256 txIndex;
    //     uint256 from;
    //     uint256 to;
    //     address freezeToken;
    //     uint256 freezeAmount;
    //     uint256 nonce;
    //     uint64 sourceTxTimestamp;
    //     uint256 dest;
    //     uint256 destToken;
    //     bytes32 L1TXBlockHash;
    //     uint256 L1TBlockNumber;
    //     address mdcContractAddress;
    //     address managerContractAddress;
    //     uint256 ruleRootSlot;
    //     uint256 ruleVersionSlot;
    //     uint256 enableTimeSlot;
    //     bytes32 RulePreRootHash;
    // }

    // function parsePublicInput(bytes calldata proofData) external pure returns (PublicInputData memory) {
    //     return
    //         PublicInputData({
    //             sourceChainId: uint64(uint256(bytes32(proofData[544:576]))),
    //             sourceTxHash: bytes32(
    //                 (uint256(bytes32(proofData[448:480])) << 128) | uint256(bytes32(proofData[480:512]))
    //             ),
    //             txIndex: uint256(bytes32(proofData[512:544])),
    //             from: ((uint256(bytes32(proofData[576:608])))),
    //             to: ((uint256(bytes32(proofData[608:640])))),
    //             freezeToken: address(uint160(uint256(bytes32(proofData[640:672])))),
    //             freezeAmount: uint256(bytes32(proofData[672:704])),
    //             nonce: uint256(bytes32(proofData[704:736])),
    //             sourceTxTimestamp: uint64(uint256(bytes32(proofData[736:768]))),
    //             dest: ((uint256(bytes32(proofData[768:800])))),
    //             destToken: ((uint256(bytes32(proofData[800:832])))),
    //             L1TXBlockHash: bytes32(
    //                 (uint256(bytes32(proofData[384:416])) << 128) | uint256(bytes32(proofData[416:448]))
    //             ),
    //             L1TBlockNumber: uint256(bytes32(proofData[1408:1440])),
    //             mdcContractAddress: address(uint160(uint256(bytes32(proofData[2560:2592])))),
    //             managerContractAddress: address(uint160(uint256(bytes32(proofData[2592:2624])))),
    //             ruleRootSlot: ((uint256(bytes32(proofData[2816:2848])) << 128) |
    //                 uint256(bytes32(proofData[2848:2880]))),
    //             ruleVersionSlot: ((uint256(bytes32(proofData[2880:2912])) << 128) |
    //                 uint256(bytes32(proofData[2912:2944]))),
    //             enableTimeSlot: ((uint256(bytes32(proofData[2944:2976])) << 128) |
    //                 uint256(bytes32(proofData[2976:3008]))),
    //             RulePreRootHash: bytes32(
    //                 (uint256(bytes32(proofData[2624:2656])) << 128) | uint256(bytes32(proofData[2656:2688]))
    //             )
    //         });
    // }

    function parseProofData(
        bytes calldata proofData
    )
        external
        pure
        returns (bytes memory _proof, bytes32 blockHash, bytes32 toAddress, uint256 transferAmount, uint256 timestamp)
    {
        _proof = proofData[0:384];
        blockHash = bytes32((uint256(bytes32(proofData[384:416])) << 128) | uint256(bytes32(proofData[416:448])));
        toAddress = bytes32(uint256(bytes32(proofData[448:480])));
        transferAmount = uint256(bytes32(proofData[480:512]));
        timestamp = uint256(bytes32(proofData[512:544]));
    }

    function verifyProof(bytes calldata input) external returns (bool) {
        require(v_address != address(0));
        (bool success, ) = v_address.call(input);
        require(success, "verify fail");
        return success;
    }

    function verifyProofXinstance(bytes calldata input, uint256 instanceBytesLength) external view {
        require(IVerifierRouter(v_address).verify(input, instanceBytesLength), "verify fail");
    }

    function encodeRawDatas(
        address[] calldata dealers,
        address[] calldata ebcs,
        uint64[] calldata chainIds,
        address ebc,
        RuleLib.Rule calldata rule
    ) external pure returns (bytes memory rawDatas) {
        return abi.encode(dealers, ebcs, chainIds, ebc, rule);
    }

    function decodeRawDatas(
        bytes calldata rawDatas
    )
        external
        pure
        returns (
            address[] memory dealers,
            address[] memory ebcs,
            uint64[] memory chainIds,
            address ebc,
            RuleLib.Rule memory rule
        )
    {
        (dealers, ebcs, chainIds, ebc, rule) = abi.decode(
            rawDatas,
            (address[], address[], uint64[], address, RuleLib.Rule)
        );
    }

    function createFreezeTokenSlotKey(uint256 chainId, uint256 token) external pure returns (uint256 slotK) {
        slotK = uint256(abi.encode(abi.encode(uint64(chainId), token).hash(), 3).hash());
    }

    function createChainInfoSlotKey(uint256 chainId) external pure returns (uint256 slotK) {
        slotK = uint256(abi.encode(chainId, 2).hash());
    }

    function createEncodeRule(RuleLib.Rule calldata rule) external pure returns (uint256 encodeRule) {
        encodeRule = uint256(abi.encode(rule).hash());
    }

    // function calculateDestAmount(
    //     RuleLib.Rule calldata rule,
    //     uint64 chainId,
    //     uint256 amount
    // ) external view returns (uint256 destAmount) {
    //     RuleLib.RuleOneway memory ro = RuleLib.convertToOneway(rule, chainId);
    //     destAmount = IOREventBinding(ebc_address).getResponseAmountFromIntent(
    //         IOREventBinding(ebc_address).getResponseIntent(amount, ro)
    //     );
    // }

    function parseSourceProof(bytes calldata proofData) external pure returns (HelperLib.PublicInputDataSource memory) {
        return proofData.parsePublicInputSource();
    }

    function parseDestProof(bytes calldata proofData) external pure returns (HelperLib.PublicInputDataDest memory) {
        return proofData.parsePublicInputDest();
    }

    function encodeResponseMakers(uint256[] calldata responseMakers) external pure returns (bytes memory) {
        return abi.encode(responseMakers);
    }

    function calculateDestAmount(
        RuleLib.Rule calldata rule,
        address ebc,
        uint64 chain_id,
        uint256 amount
    ) external pure returns (uint256 destAmount) {
        RuleLib.RuleOneway memory ro = RuleLib.convertToOneway(rule, chain_id);
        destAmount = IOREventBinding(ebc).getResponseAmountFromIntent(
            IOREventBinding(ebc).getResponseIntent(amount, ro)
        );
    }
}
