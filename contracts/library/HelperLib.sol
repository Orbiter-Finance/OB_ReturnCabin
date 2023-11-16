// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

library HelperLib {
    function hash(bytes memory data) internal pure returns (bytes32) {
        return keccak256(data);
    }

    function includes(uint256[] memory arr, uint256 element) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; ) {
            if (element == arr[i]) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }

    function arrayIncludes(uint256[] memory arr, uint256[] memory elements) internal pure returns (bool) {
        for (uint256 i = 0; i < elements.length; i++) {
            bool ic = false;
            for (uint256 j = 0; j < arr.length; ) {
                if (elements[i] == arr[j]) {
                    ic = true;
                    break;
                }
                unchecked {
                    j++;
                }
            }

            if (!ic) return false;

            unchecked {
                i++;
            }
        }
        return true;
    }

    function includes(address[] memory arr, address element) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; ) {
            if (element == arr[i]) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }

    function arrayIncludes(address[] memory arr, address[] memory elements) internal pure returns (bool) {
        for (uint256 i = 0; i < elements.length; i++) {
            bool ic = false;
            for (uint256 j = 0; j < arr.length; ) {
                if (elements[i] == arr[j]) {
                    ic = true;
                    break;
                }
                unchecked {
                    j++;
                }
            }

            if (!ic) return false;

            unchecked {
                i++;
            }
        }
        return true;
    }

    function calculateChallengeIdentNum(
        uint64 sourceTxTime,
        uint64 sourceChainId,
        uint64 sourceTxBlockNum,
        uint64 sourceTxIndex
    ) internal pure returns (uint256) {
        uint256 challengeIdentNum;

        assembly {
            challengeIdentNum := add(
                shl(192, sourceTxTime),
                add(shl(128, sourceChainId), add(shl(64, sourceTxBlockNum), sourceTxIndex))
            )
        }
        return challengeIdentNum;
    }

    struct PublicInputData {
        bytes32 tx_hash;
        uint64 chain_id;
        uint256 index;
        uint256 from;
        address to;
        address token;
        uint256 amount;
        uint256 nonce;
        uint256 time_stamp;
        address dest;
        address dest_token;
        address mdc_contract_address;
        address manage_contract_address;
        uint256 mdc_rule_root_slot;
        uint256 mdc_rule_version_slot;
        uint256 mdc_rule_enable_time_slot;
        uint8 mdc_column_array_hash_slot;
        uint8 mdc_response_makers_hash_slot;
        uint256 manage_source_chain_info_slot;
        uint256 manage_source_chain_mainnet_token_info_slot;
        uint256 manage_dest_chain_mainnet_token_slot;
        uint8 manage_challenge_user_ratio_slot;
        bytes32 mdc_current_rule_root;
        uint256 mdc_current_rule_enable_time;
        bytes32 mdc_current_column_array_hash;
        uint256 mdc_current_response_makers_hash;
        uint64 min_verify_challenge_src_tx_second;
        uint64 max_verify_challenge_src_tx_second;
        uint64 min_verify_challenge_dest_tx_second;
        uint64 max_verify_challenge_dest_tx_second;
        address manage_current_source_chain_mainnet_token;
        address manage_current_dest_chain_mainnet_token;
        uint64 manage_current_challenge_user_ratio;
        uint256 mdc_next_rule_enable_time;
        bytes32 mdc_current_rule_value_hash;
    }

    function parsePublicInput(bytes calldata proofData) internal pure returns (PublicInputData memory) {
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
                chain_id: uint64(
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 2:TransactionSplitStart + SplitStep * 3])
                    )
                ),
                index: uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 3:TransactionSplitStart + SplitStep * 4])
                ),
                from: (
                    (
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
                mdc_rule_root_slot: ((uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 2:MdcContractSplitStart + SplitStep * 3])
                ) << 128) |
                    uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 3:MdcContractSplitStart + SplitStep * 4])
                    )),
                mdc_rule_version_slot: ((uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 4:MdcContractSplitStart + SplitStep * 5])
                ) << 128) |
                    uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 5:MdcContractSplitStart + SplitStep * 6])
                    )),
                mdc_rule_enable_time_slot: ((uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 6:MdcContractSplitStart + SplitStep * 7])
                ) << 128) |
                    uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 7:MdcContractSplitStart + SplitStep * 8])
                    )),
                mdc_column_array_hash_slot: uint8(
                    (uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 8:MdcContractSplitStart + SplitStep * 9])
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 9:MdcContractSplitStart + SplitStep * 10]
                            )
                        )
                ),
                mdc_response_makers_hash_slot: uint8(
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
                manage_source_chain_info_slot: uint256(
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
                manage_source_chain_mainnet_token_info_slot: uint256(
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
                manage_dest_chain_mainnet_token_slot: uint256(
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
                manage_challenge_user_ratio_slot: uint8(
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
                mdc_current_response_makers_hash: uint256(
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
}
