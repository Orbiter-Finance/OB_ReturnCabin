// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

library Era2MainnetLib {
    uint256 constant ProofLength = 384;
    uint256 constant SplitStep = 32;
    uint256 constant TransactionSplitStart = ProofLength;
    uint256 constant TrackBlockSplitStart = TransactionSplitStart + SplitStep * 14;
    uint256 constant MdcContractSplitStart = TrackBlockSplitStart + SplitStep * 20;

    function checkSourceTxProof(bytes calldata proofData) internal pure returns (bool proofMatch) {
        bytes32 ob_mdc_contracts_current_block_hash = bytes32(
            ((uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 28:MdcContractSplitStart + SplitStep * 29])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 29:MdcContractSplitStart + SplitStep * 30])
                ))
        );
        bytes32 ob_mdc_contracts_next_block_hash = bytes32(
            ((uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 30:MdcContractSplitStart + SplitStep * 31])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 31:MdcContractSplitStart + SplitStep * 32])
                ))
        );
        bytes32 ob_manager_contracts_current_block_hash = bytes32(
            ((uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 32:MdcContractSplitStart + SplitStep * 33])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 33:MdcContractSplitStart + SplitStep * 34])
                ))
        );
        bytes32 ob_manager_contracts_next_block_hash = bytes32(
            ((uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 34:MdcContractSplitStart + SplitStep * 35])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 35:MdcContractSplitStart + SplitStep * 36])
                ))
        );

        bytes32 ob_mdc_contracts_current_batch_target_block_hash = bytes32(
            ((uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 6:TrackBlockSplitStart + SplitStep * 7])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 7:TrackBlockSplitStart + SplitStep * 8])))
        );

        bytes32 ob_mdc_contracts_next_batch_target_block_hash = bytes32(
            ((uint256(
                bytes32(proofData[TrackBlockSplitStart + SplitStep * 10:TrackBlockSplitStart + SplitStep * 11])
            ) << 128) |
                uint256(
                    bytes32(proofData[TrackBlockSplitStart + SplitStep * 11:TrackBlockSplitStart + SplitStep * 12])
                ))
        );

        bytes32 ob_manager_contracts_current_batch_target_block_hash = bytes32(
            ((uint256(
                bytes32(proofData[TrackBlockSplitStart + SplitStep * 14:TrackBlockSplitStart + SplitStep * 15])
            ) << 128) |
                uint256(
                    bytes32(proofData[TrackBlockSplitStart + SplitStep * 15:TrackBlockSplitStart + SplitStep * 16])
                ))
        );

        bytes32 ob_manager_contracts_next_batch_target_block_hash = bytes32(
            ((uint256(
                bytes32(proofData[TrackBlockSplitStart + SplitStep * 18:TrackBlockSplitStart + SplitStep * 19])
            ) << 128) |
                uint256(
                    bytes32(proofData[TrackBlockSplitStart + SplitStep * 19:TrackBlockSplitStart + SplitStep * 20])
                ))
        );
        bytes8 mdc_current_rule_enable_time = bytes8(
            bytes8(
                proofData[MdcContractSplitStart + SplitStep * 6 + SplitStep / 2:MdcContractSplitStart +
                    SplitStep *
                    6 +
                    SplitStep /
                    2 +
                    SplitStep /
                    4]
            )
        );
        bytes8 time_stamp = bytes8(
            uint64(
                uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 11:TransactionSplitStart + SplitStep * 12])
                )
            )
        );
        bytes8 mdc_next_rule_enable_time = (
            bytes8(
                proofData[MdcContractSplitStart + SplitStep * 12 + SplitStep / 2:MdcContractSplitStart +
                    SplitStep *
                    12 +
                    SplitStep /
                    2 +
                    SplitStep /
                    4]
            )
        );

        proofMatch =
            ob_mdc_contracts_current_batch_target_block_hash == ob_mdc_contracts_current_block_hash &&
            ob_mdc_contracts_next_batch_target_block_hash == ob_mdc_contracts_next_block_hash &&
            ob_manager_contracts_current_batch_target_block_hash == ob_manager_contracts_current_block_hash &&
            ob_manager_contracts_next_batch_target_block_hash == ob_manager_contracts_next_block_hash &&
            ((mdc_current_rule_enable_time <= time_stamp && time_stamp < mdc_next_rule_enable_time) ||
                (mdc_current_rule_enable_time == mdc_next_rule_enable_time && mdc_next_rule_enable_time < time_stamp));
    }

    function checkDestTxProof(bytes calldata proofData) internal pure returns (bool proofMatch) {
        proofMatch =
            ((uint256(bytes32(proofData[TransactionSplitStart:TransactionSplitStart + SplitStep])) << 128) |
                uint256(bytes32(proofData[TransactionSplitStart + SplitStep:TransactionSplitStart + SplitStep * 2]))) ==
            ((uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 2:TrackBlockSplitStart + SplitStep * 3])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 3:TrackBlockSplitStart + SplitStep * 4])));
    }

    function parsePublicInputSource(
        bytes calldata proofData
    ) internal pure returns (PublicInputParseLib.PublicInputDataSource memory publicInputSource) {
        uint256 manage_current_source_chain_info = uint256(
            (uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 16:MdcContractSplitStart + SplitStep * 17])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 17:MdcContractSplitStart + SplitStep * 18])
                )
        );
        publicInputSource = PublicInputParseLib.PublicInputDataSource({
            tx_hash: bytes32(
                (uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 2:TransactionSplitStart + SplitStep * 3])
                ) << 128) |
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 3:TransactionSplitStart + SplitStep * 4])
                    )
            ),
            chain_id: uint64(
                uint256(bytes32(proofData[TransactionSplitStart + SplitStep * 4:TransactionSplitStart + SplitStep * 5]))
            ),
            index: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 5:TransactionSplitStart + SplitStep * 6])
            ),
            from: (
                (
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 6:TransactionSplitStart + SplitStep * 7])
                    )
                )
            ),
            to: (
                (
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 7:TransactionSplitStart + SplitStep * 8])
                    )
                )
            ),
            token: address(
                uint160(
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 8:TransactionSplitStart + SplitStep * 9])
                    )
                )
            ),
            amount: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 9:TransactionSplitStart + SplitStep * 10])
            ),
            nonce: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 10:TransactionSplitStart + SplitStep * 11])
            ),
            time_stamp: uint64(
                uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 11:TransactionSplitStart + SplitStep * 12])
                )
            ),
            dest: address(
                uint160(
                    uint256(
                        bytes32(
                            proofData[TransactionSplitStart + SplitStep * 12:TransactionSplitStart + SplitStep * 13]
                        )
                    )
                )
            ),
            dest_token: address(
                uint160(
                    uint256(
                        bytes32(
                            proofData[TransactionSplitStart + SplitStep * 13:TransactionSplitStart + SplitStep * 14]
                        )
                    )
                )
            ),
            mdc_contract_address: address(
                uint160(uint256(bytes32(proofData[MdcContractSplitStart:MdcContractSplitStart + SplitStep])))
            ),
            manage_contract_address: address(
                uint160(
                    uint256(bytes32(proofData[MdcContractSplitStart + SplitStep:MdcContractSplitStart + SplitStep * 2]))
                )
            ),
            mdc_rule_root_slot: ((uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 2:MdcContractSplitStart + SplitStep * 3])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 3:MdcContractSplitStart + SplitStep * 4])
                )),
            mdc_current_rule_root: bytes32(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 4:MdcContractSplitStart + SplitStep * 5])
                ) << 128) |
                    uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 5:MdcContractSplitStart + SplitStep * 6])
                    )
            ),
            mdc_current_rule_enable_time: uint64(
                bytes8(
                    proofData[MdcContractSplitStart + SplitStep * 6 + SplitStep / 2:MdcContractSplitStart +
                        SplitStep *
                        6 +
                        SplitStep /
                        2 +
                        SplitStep /
                        4]
                )
            ),
            mdc_current_column_array_hash: (
                bytes32(
                    (uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 8:MdcContractSplitStart + SplitStep * 9])
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 9:MdcContractSplitStart + SplitStep * 10]
                            )
                        )
                )
            ),
            mdc_current_response_makers_hash: uint256(
                bytes32(
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
                )
            ),
            mdc_next_rule_enable_time: uint64(
                bytes8(
                    proofData[MdcContractSplitStart + SplitStep * 12 + SplitStep / 2:MdcContractSplitStart +
                        SplitStep *
                        12 +
                        SplitStep /
                        2 +
                        SplitStep /
                        4]
                )
            ),
            manager_current_enable_time: uint64(
                bytes8(
                    proofData[MdcContractSplitStart + SplitStep * 14 + SplitStep / 2:MdcContractSplitStart +
                        SplitStep *
                        14 +
                        SplitStep /
                        2 +
                        SplitStep /
                        4]
                )
            ),
            manage_current_source_chain_mainnet_token: address(
                uint160(
                    uint256(
                        bytes32(
                            (uint256(
                                bytes32(
                                    proofData[MdcContractSplitStart + SplitStep * 18:MdcContractSplitStart +
                                        SplitStep *
                                        19]
                                )
                            ) << 128) |
                                uint256(
                                    bytes32(
                                        proofData[MdcContractSplitStart + SplitStep * 19:MdcContractSplitStart +
                                            SplitStep *
                                            20]
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
                                    proofData[MdcContractSplitStart + SplitStep * 20:MdcContractSplitStart +
                                        SplitStep *
                                        21]
                                )
                            ) << 128) |
                                uint256(
                                    bytes32(
                                        proofData[MdcContractSplitStart + SplitStep * 21:MdcContractSplitStart +
                                            SplitStep *
                                            22]
                                    )
                                )
                        )
                    )
                )
            ),
            manage_current_challenge_user_ratio: uint64(
                bytes8(
                    proofData[MdcContractSplitStart + SplitStep * 23 + SplitStep / 2:MdcContractSplitStart +
                        SplitStep *
                        23 +
                        SplitStep /
                        2 +
                        SplitStep /
                        4]
                )
            ),
            manager_next_enable_time: uint64(
                bytes8(
                    proofData[MdcContractSplitStart + SplitStep * 24 + SplitStep / 2:MdcContractSplitStart +
                        SplitStep *
                        24 +
                        SplitStep /
                        2 +
                        SplitStep /
                        4]
                )
            ),
            mdc_current_rule_value_hash: bytes32(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 26:MdcContractSplitStart + SplitStep * 27])
                ) << 128) |
                    uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 27:MdcContractSplitStart + SplitStep * 28]
                        )
                    )
            ),
            min_verify_challenge_src_tx_second: uint64((manage_current_source_chain_info << 192) >> 192),
            max_verify_challenge_src_tx_second: uint64((manage_current_source_chain_info << 128) >> 192),
            min_verify_challenge_dest_tx_second: uint64((manage_current_source_chain_info << 64) >> 192),
            max_verify_challenge_dest_tx_second: uint64(manage_current_source_chain_info >> 192),
            merkle_roots: new bytes32[](4)
        });

        publicInputSource.merkle_roots[0] = bytes32(
            ((uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 4:TrackBlockSplitStart + SplitStep * 5])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 5:TrackBlockSplitStart + SplitStep * 6])))
        );
        publicInputSource.merkle_roots[1] = bytes32(
            ((uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 8:TrackBlockSplitStart + SplitStep * 9])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 9:TrackBlockSplitStart + SplitStep * 10])))
        );
        publicInputSource.merkle_roots[2] = bytes32(
            ((uint256(
                bytes32(proofData[TrackBlockSplitStart + SplitStep * 12:TrackBlockSplitStart + SplitStep * 13])
            ) << 128) |
                uint256(
                    bytes32(proofData[TrackBlockSplitStart + SplitStep * 13:TrackBlockSplitStart + SplitStep * 14])
                ))
        );
        publicInputSource.merkle_roots[3] = bytes32(
            ((uint256(
                bytes32(proofData[TrackBlockSplitStart + SplitStep * 16:TrackBlockSplitStart + SplitStep * 17])
            ) << 128) |
                uint256(
                    bytes32(proofData[TrackBlockSplitStart + SplitStep * 17:TrackBlockSplitStart + SplitStep * 18])
                ))
        );
    }

    function parsePublicInputDest(
        bytes calldata proofData
    ) internal pure returns (PublicInputParseLib.PublicInputDataDest memory publicInputDest) {
        publicInputDest = PublicInputParseLib.PublicInputDataDest({
            chain_id: uint64(
                uint256(bytes32(proofData[TransactionSplitStart + SplitStep * 4:TransactionSplitStart + SplitStep * 5]))
            ),
            from: (
                (
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 6:TransactionSplitStart + SplitStep * 7])
                    )
                )
            ),
            to: (
                (
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 7:TransactionSplitStart + SplitStep * 8])
                    )
                )
            ),
            token: (
                (
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 8:TransactionSplitStart + SplitStep * 9])
                    )
                )
            ),
            amount: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 9:TransactionSplitStart + SplitStep * 10])
            ),
            time_stamp: uint64(
                uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 11:TransactionSplitStart + SplitStep * 12])
                )
            ),
            merkle_roots: new bytes32[](1)
        });
        publicInputDest.merkle_roots[0] = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart:TrackBlockSplitStart + SplitStep])) << 128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep:TrackBlockSplitStart + SplitStep * 2]))
        );
    }
}

library Mainnet2EraLib {
    uint256 constant ProofLength = 384;
    uint256 constant SplitStep = 32;
    uint256 constant TransactionSplitStart = ProofLength;
    uint256 constant TrackBlockSplitStart = TransactionSplitStart + SplitStep * 14;
    uint256 constant TrackBlockSplitStartDest = TransactionSplitStart + SplitStep * 17;
    uint256 constant MdcContractSplitStart = TrackBlockSplitStart + SplitStep * 20;

    function checkSourceTxProof(bytes calldata proofData) internal pure returns (bool proofMatch) {
        bytes32 tx_block_hash = bytes32(
            (uint256(bytes32(proofData[TransactionSplitStart:TransactionSplitStart + SplitStep])) << 128) |
                uint256(bytes32(proofData[TransactionSplitStart + SplitStep:TransactionSplitStart + SplitStep * 2]))
        );

        bytes32 ob_mdc_contracts_current_block_hash = bytes32(
            (uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 28:MdcContractSplitStart + SplitStep * 29])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 29:MdcContractSplitStart + SplitStep * 30])
                )
        );

        bytes32 ob_mdc_contracts_next_block_hash = bytes32(
            (uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 30:MdcContractSplitStart + SplitStep * 31])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 31:MdcContractSplitStart + SplitStep * 32])
                )
        );

        bytes32 ob_manager_contracts_current_block_hash = bytes32(
            (uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 32:MdcContractSplitStart + SplitStep * 33])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 33:MdcContractSplitStart + SplitStep * 34])
                )
        );

        bytes32 ob_manager_contracts_next_block_hash = bytes32(
            (uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 34:MdcContractSplitStart + SplitStep * 35])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 35:MdcContractSplitStart + SplitStep * 36])
                )
        );

        bytes32 tx_batch_target_block_hash = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 2:TrackBlockSplitStart + SplitStep * 3])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 3:TrackBlockSplitStart + SplitStep * 4]))
        );

        bytes32 ob_mdc_contracts_current_batch_target_block_hash = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 6:TrackBlockSplitStart + SplitStep * 7])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 7:TrackBlockSplitStart + SplitStep * 8]))
        );

        bytes32 ob_mdc_contracts_next_batch_target_block_hash = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 10:TrackBlockSplitStart + SplitStep * 11])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 11:TrackBlockSplitStart + SplitStep * 12]))
        );

        bytes32 ob_manager_contracts_current_batch_target_block_hash = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 14:TrackBlockSplitStart + SplitStep * 15])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 15:TrackBlockSplitStart + SplitStep * 16]))
        );

        bytes32 ob_manager_contracts_next_batch_target_block_hash = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 18:TrackBlockSplitStart + SplitStep * 19])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 19:TrackBlockSplitStart + SplitStep * 20]))
        );

        bytes8 time_stamp = bytes8(
            uint64(
                uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 11:TransactionSplitStart + SplitStep * 12])
                )
            )
        );

        bytes8 mdc_current_rule_enable_time = bytes8(
            bytes8(
                proofData[MdcContractSplitStart + SplitStep * 6 + SplitStep / 2:MdcContractSplitStart +
                    SplitStep *
                    6 +
                    SplitStep /
                    2 +
                    SplitStep /
                    4]
            )
        );

        bytes8 mdc_next_rule_enable_time = (
            bytes8(
                proofData[MdcContractSplitStart + SplitStep * 12 + SplitStep / 2:MdcContractSplitStart +
                    SplitStep *
                    12 +
                    SplitStep /
                    2 +
                    SplitStep /
                    4]
            )
        );

        proofMatch =
            tx_batch_target_block_hash == tx_block_hash &&
            ob_mdc_contracts_current_batch_target_block_hash == ob_mdc_contracts_current_block_hash &&
            ob_mdc_contracts_next_batch_target_block_hash == ob_mdc_contracts_next_block_hash &&
            ob_manager_contracts_current_batch_target_block_hash == ob_manager_contracts_current_block_hash &&
            ob_manager_contracts_next_batch_target_block_hash == ob_manager_contracts_next_block_hash &&
            ((mdc_current_rule_enable_time <= time_stamp && time_stamp < mdc_next_rule_enable_time) ||
                (mdc_current_rule_enable_time == mdc_next_rule_enable_time && mdc_next_rule_enable_time < time_stamp));
    }

    function checkDestTxProof(bytes calldata proofData) internal pure returns (bool proofMatch) {
        proofMatch =
            (uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 14:TransactionSplitStart + SplitStep * 15])
            ) << 128) |
                uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 15:TransactionSplitStart + SplitStep * 16])
                ) ==
            ((uint256(
                bytes32(proofData[TrackBlockSplitStartDest + SplitStep * 2:TrackBlockSplitStartDest + SplitStep * 3])
            ) << 128) |
                uint256(
                    bytes32(
                        proofData[TrackBlockSplitStartDest + SplitStep * 3:TrackBlockSplitStartDest + SplitStep * 4]
                    )
                ));
    }

    function parsePublicInputSource(
        bytes calldata proofData
    ) internal pure returns (PublicInputParseLib.PublicInputDataSource memory publicInputSource) {
        uint256 manage_current_source_chain_info = uint256(
            (uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 16:MdcContractSplitStart + SplitStep * 17])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 17:MdcContractSplitStart + SplitStep * 18])
                )
        );

        publicInputSource = PublicInputParseLib.PublicInputDataSource({
            tx_hash: bytes32(
                (uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 2:TransactionSplitStart + SplitStep * 3])
                ) << 128) |
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 3:TransactionSplitStart + SplitStep * 4])
                    )
            ),
            chain_id: uint64(
                uint256(bytes32(proofData[TransactionSplitStart + SplitStep * 4:TransactionSplitStart + SplitStep * 5]))
            ),
            index: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 5:TransactionSplitStart + SplitStep * 6])
            ),
            from: (
                (
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 6:TransactionSplitStart + SplitStep * 7])
                    )
                )
            ),
            to: (
                (
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 7:TransactionSplitStart + SplitStep * 8])
                    )
                )
            ),
            token: address(
                uint160(
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 8:TransactionSplitStart + SplitStep * 9])
                    )
                )
            ),
            amount: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 9:TransactionSplitStart + SplitStep * 10])
            ),
            nonce: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 10:TransactionSplitStart + SplitStep * 11])
            ),
            time_stamp: uint64(
                uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 11:TransactionSplitStart + SplitStep * 12])
                )
            ),
            dest: address(
                uint160(
                    uint256(
                        bytes32(
                            proofData[TransactionSplitStart + SplitStep * 12:TransactionSplitStart + SplitStep * 13]
                        )
                    )
                )
            ),
            dest_token: address(
                uint160(
                    uint256(
                        bytes32(
                            proofData[TransactionSplitStart + SplitStep * 13:TransactionSplitStart + SplitStep * 14]
                        )
                    )
                )
            ),
            mdc_contract_address: address(
                uint160(uint256(bytes32(proofData[MdcContractSplitStart:MdcContractSplitStart + SplitStep])))
            ),
            manage_contract_address: address(
                uint160(
                    uint256(bytes32(proofData[MdcContractSplitStart + SplitStep:MdcContractSplitStart + SplitStep * 2]))
                )
            ),
            mdc_rule_root_slot: ((uint256(
                bytes32(proofData[MdcContractSplitStart + SplitStep * 2:MdcContractSplitStart + SplitStep * 3])
            ) << 128) |
                uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 3:MdcContractSplitStart + SplitStep * 4])
                )),
            mdc_current_rule_root: bytes32(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 4:MdcContractSplitStart + SplitStep * 5])
                ) << 128) |
                    uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 5:MdcContractSplitStart + SplitStep * 6])
                    )
            ),
            mdc_current_rule_enable_time: uint64(
                bytes8(
                    proofData[MdcContractSplitStart + SplitStep * 6 + SplitStep / 2:MdcContractSplitStart +
                        SplitStep *
                        6 +
                        SplitStep /
                        2 +
                        SplitStep /
                        4]
                )
            ),
            mdc_current_column_array_hash: (
                bytes32(
                    (uint256(
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 8:MdcContractSplitStart + SplitStep * 9])
                    ) << 128) |
                        uint256(
                            bytes32(
                                proofData[MdcContractSplitStart + SplitStep * 9:MdcContractSplitStart + SplitStep * 10]
                            )
                        )
                )
            ),
            mdc_current_response_makers_hash: uint256(
                bytes32(
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
                )
            ),
            mdc_next_rule_enable_time: uint64(
                bytes8(
                    proofData[MdcContractSplitStart + SplitStep * 12 + SplitStep / 2:MdcContractSplitStart +
                        SplitStep *
                        12 +
                        SplitStep /
                        2 +
                        SplitStep /
                        4]
                )
            ),
            manager_current_enable_time: uint64(
                bytes8(
                    proofData[MdcContractSplitStart + SplitStep * 14 + SplitStep / 2:MdcContractSplitStart +
                        SplitStep *
                        14 +
                        SplitStep /
                        2 +
                        SplitStep /
                        4]
                )
            ),
            manage_current_source_chain_mainnet_token: address(
                uint160(
                    uint256(
                        bytes32(
                            (uint256(
                                bytes32(
                                    proofData[MdcContractSplitStart + SplitStep * 18:MdcContractSplitStart +
                                        SplitStep *
                                        19]
                                )
                            ) << 128) |
                                uint256(
                                    bytes32(
                                        proofData[MdcContractSplitStart + SplitStep * 19:MdcContractSplitStart +
                                            SplitStep *
                                            20]
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
                                    proofData[MdcContractSplitStart + SplitStep * 20:MdcContractSplitStart +
                                        SplitStep *
                                        21]
                                )
                            ) << 128) |
                                uint256(
                                    bytes32(
                                        proofData[MdcContractSplitStart + SplitStep * 21:MdcContractSplitStart +
                                            SplitStep *
                                            22]
                                    )
                                )
                        )
                    )
                )
            ),
            manage_current_challenge_user_ratio: uint64(
                bytes8(
                    proofData[MdcContractSplitStart + SplitStep * 23 + SplitStep / 2:MdcContractSplitStart +
                        SplitStep *
                        23 +
                        SplitStep /
                        2 +
                        SplitStep /
                        4]
                )
            ),
            manager_next_enable_time: uint64(
                bytes8(
                    proofData[MdcContractSplitStart + SplitStep * 24 + SplitStep / 2:MdcContractSplitStart +
                        SplitStep *
                        24 +
                        SplitStep /
                        2 +
                        SplitStep /
                        4]
                )
            ),
            mdc_current_rule_value_hash: bytes32(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 26:MdcContractSplitStart + SplitStep * 27])
                ) << 128) |
                    uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 27:MdcContractSplitStart + SplitStep * 28]
                        )
                    )
            ),
            min_verify_challenge_src_tx_second: uint64((manage_current_source_chain_info << 192) >> 192),
            max_verify_challenge_src_tx_second: uint64((manage_current_source_chain_info << 128) >> 192),
            min_verify_challenge_dest_tx_second: uint64((manage_current_source_chain_info << 64) >> 192),
            max_verify_challenge_dest_tx_second: uint64(manage_current_source_chain_info >> 192),
            merkle_roots: new bytes32[](5)
        });

        publicInputSource.merkle_roots[0] = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart:TrackBlockSplitStart + SplitStep])) << 128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep:TrackBlockSplitStart + SplitStep * 2]))
        );
        publicInputSource.merkle_roots[1] = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 4:TrackBlockSplitStart + SplitStep * 5])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 5:TrackBlockSplitStart + SplitStep * 6]))
        );
        publicInputSource.merkle_roots[2] = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 8:TrackBlockSplitStart + SplitStep * 9])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 9:TrackBlockSplitStart + SplitStep * 10]))
        );
        publicInputSource.merkle_roots[3] = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 12:TrackBlockSplitStart + SplitStep * 13])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 13:TrackBlockSplitStart + SplitStep * 14]))
        );
        publicInputSource.merkle_roots[4] = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 16:TrackBlockSplitStart + SplitStep * 17])) <<
                128) |
                uint256(bytes32(proofData[TrackBlockSplitStart + SplitStep * 17:TrackBlockSplitStart + SplitStep * 18]))
        );
    }

    function parsePublicInputDest(
        bytes calldata proofData
    ) internal pure returns (PublicInputParseLib.PublicInputDataDest memory publicInputDest) {
        publicInputDest = PublicInputParseLib.PublicInputDataDest({
            chain_id: uint64(
                uint256(bytes32(proofData[TransactionSplitStart + SplitStep * 4:TransactionSplitStart + SplitStep * 5]))
            ),
            from: (
                (
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 6:TransactionSplitStart + SplitStep * 7])
                    )
                )
            ),
            to: (
                (
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 7:TransactionSplitStart + SplitStep * 8])
                    )
                )
            ),
            token: (
                (
                    uint256(
                        bytes32(proofData[TransactionSplitStart + SplitStep * 8:TransactionSplitStart + SplitStep * 9])
                    )
                )
            ),
            amount: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 9:TransactionSplitStart + SplitStep * 10])
            ),
            time_stamp: uint64(
                uint256(
                    bytes32(proofData[TransactionSplitStart + SplitStep * 11:TransactionSplitStart + SplitStep * 12])
                )
            ),
            merkle_roots: new bytes32[](1)
        });
        publicInputDest.merkle_roots[0] = bytes32(
            (uint256(bytes32(proofData[TrackBlockSplitStartDest:TrackBlockSplitStartDest + SplitStep])) << 128) |
                uint256(
                    bytes32(proofData[TrackBlockSplitStartDest + SplitStep:TrackBlockSplitStartDest + SplitStep * 2])
                )
        );
    }
}

library PublicInputParseLib {
    struct PublicInputDataSource {
        bytes32 tx_hash;
        uint64 chain_id;
        uint256 index;
        uint256 from;
        uint256 to;
        address token;
        uint256 amount;
        uint256 nonce;
        uint64 time_stamp;
        address dest;
        address dest_token;
        address mdc_contract_address;
        address manage_contract_address;
        uint256 mdc_rule_root_slot;
        bytes32 mdc_current_rule_root;
        uint64 mdc_current_rule_enable_time;
        bytes32 mdc_current_column_array_hash;
        uint256 mdc_current_response_makers_hash;
        uint64 mdc_next_rule_enable_time;
        uint64 manager_current_enable_time;
        // bytes32 manage_current_source_chain_info;
        address manage_current_source_chain_mainnet_token;
        address manage_current_dest_chain_mainnet_token;
        uint64 manage_current_challenge_user_ratio;
        uint64 manager_next_enable_time;
        bytes32 mdc_current_rule_value_hash;
        uint64 min_verify_challenge_src_tx_second;
        uint64 max_verify_challenge_src_tx_second;
        uint64 min_verify_challenge_dest_tx_second;
        uint64 max_verify_challenge_dest_tx_second;
        bytes32[] merkle_roots;
    }

    struct PublicInputDataDest {
        uint64 chain_id;
        uint256 from;
        uint256 to;
        uint256 token;
        uint256 amount;
        uint64 time_stamp;
        bytes32[] merkle_roots;
    }
}
