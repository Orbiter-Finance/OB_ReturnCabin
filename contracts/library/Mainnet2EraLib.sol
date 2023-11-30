// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {HelperLib} from "../library/HelperLib.sol";

library Mainnet2EraLib {
    function checkSourceTxProof(bytes calldata zkProof) internal pure returns (bool proofMatch) {
        uint256 ProofLength = 384;
        uint256 SplitStep = 32;
        uint256 TransactionSplitStart = ProofLength;
        uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 14;
        uint256 MdcContractSplitStart = TrackBlockSplitStart + SplitStep * 12;
        uint256 original_tx_block_hash = ((uint256(
            bytes32(zkProof[TransactionSplitStart:TransactionSplitStart + SplitStep])
        ) << 128) | uint256(bytes32(zkProof[TransactionSplitStart + SplitStep:TransactionSplitStart + SplitStep * 2])));
        uint256 original_tx_batch_target_block_hash = ((uint256(
            bytes32(zkProof[TrackBlockSplitStart + SplitStep * 2:TrackBlockSplitStart + SplitStep * 3])
        ) << 128) |
            uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 3:TrackBlockSplitStart + SplitStep * 4])));

        uint256 ob_contracts_current_block_hash = (uint256(
            bytes32(zkProof[MdcContractSplitStart + SplitStep * 40:MdcContractSplitStart + SplitStep * 41])
        ) << 128) |
            uint256(bytes32(zkProof[MdcContractSplitStart + SplitStep * 41:MdcContractSplitStart + SplitStep * 42]));

        uint256 ob_contracts_current_batch_target_block_hash = (uint256(
            bytes32(zkProof[TrackBlockSplitStart + SplitStep * 6:TrackBlockSplitStart + SplitStep * 7])
        ) << 128) |
            uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 7:TrackBlockSplitStart + SplitStep * 8]));

        uint256 ob_contracts_next_block_hash = (uint256(
            bytes32(zkProof[MdcContractSplitStart + SplitStep * 42:MdcContractSplitStart + SplitStep * 43])
        ) << 128) |
            uint256(bytes32(zkProof[MdcContractSplitStart + SplitStep * 43:MdcContractSplitStart + SplitStep * 44]));
        uint256 ob_contracts_next_batch_target_block_hash = (uint256(
            bytes32(zkProof[TrackBlockSplitStart + SplitStep * 10:TrackBlockSplitStart + SplitStep * 11])
        ) << 128) |
            uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 11:TrackBlockSplitStart + SplitStep * 12]));

        proofMatch =
            original_tx_block_hash == original_tx_batch_target_block_hash &&
            ob_contracts_current_block_hash == ob_contracts_current_batch_target_block_hash &&
            ob_contracts_next_block_hash == ob_contracts_next_batch_target_block_hash;
    }

    function checkDestTxProof(bytes calldata zkProof) internal pure returns (bool proofMatch) {
        uint256 ProofLength = 384;
        uint256 SplitStep = 32;
        uint256 TransactionSplitStart = ProofLength; // 384 is proof length
        uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 17;
        proofMatch =
            (uint256(bytes32(zkProof[TransactionSplitStart + SplitStep * 14:TransactionSplitStart + SplitStep * 15])) <<
                128) |
                uint256(
                    bytes32(zkProof[TransactionSplitStart + SplitStep * 15:TransactionSplitStart + SplitStep * 16])
                ) ==
            ((uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 2:TrackBlockSplitStart + SplitStep * 3])) <<
                128) |
                uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 3:TrackBlockSplitStart + SplitStep * 4])));
    }

    function parsePublicInputSource(
        bytes calldata proofData
    ) internal pure returns (HelperLib.PublicInputDataSource memory publicInputSource) {
        uint256 ProofLength = 384;
        uint256 SplitStep = 32;
        uint256 TransactionSplitStart = ProofLength;
        uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 14;
        uint256 MdcContractSplitStart = TrackBlockSplitStart + SplitStep * 12;

        publicInputSource = HelperLib.PublicInputDataSource({
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
            from: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 6:TransactionSplitStart + SplitStep * 7])
            ),
            to: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 7:TransactionSplitStart + SplitStep * 8])
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
            time_stamp: uint256(
                bytes32(proofData[TransactionSplitStart + SplitStep * 11:TransactionSplitStart + SplitStep * 12])
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
                        bytes32(proofData[MdcContractSplitStart + SplitStep * 9:MdcContractSplitStart + SplitStep * 10])
                    )
            ),
            mdc_response_makers_hash_slot: uint8(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 10:MdcContractSplitStart + SplitStep * 11])
                ) << 128) |
                    uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 11:MdcContractSplitStart + SplitStep * 12]
                        )
                    )
            ),
            manage_source_chain_info_slot: uint256(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 12:MdcContractSplitStart + SplitStep * 13])
                ) << 128) |
                    uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 13:MdcContractSplitStart + SplitStep * 14]
                        )
                    )
            ),
            manage_source_chain_mainnet_token_info_slot: uint256(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 14:MdcContractSplitStart + SplitStep * 15])
                ) << 128) |
                    uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 15:MdcContractSplitStart + SplitStep * 16]
                        )
                    )
            ),
            manage_dest_chain_mainnet_token_slot: uint256(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 16:MdcContractSplitStart + SplitStep * 17])
                ) << 128) |
                    uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 17:MdcContractSplitStart + SplitStep * 18]
                        )
                    )
            ),
            manage_challenge_user_ratio_slot: uint8(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 18:MdcContractSplitStart + SplitStep * 19])
                ) << 128) |
                    uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 19:MdcContractSplitStart + SplitStep * 20]
                        )
                    )
            ),
            mdc_current_rule_root: bytes32(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 20:MdcContractSplitStart + SplitStep * 21])
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
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 24:MdcContractSplitStart + SplitStep * 25])
                ) << 128) |
                    uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 25:MdcContractSplitStart + SplitStep * 26]
                        )
                    )
            ),
            mdc_current_response_makers_hash: uint256(
                (uint256(
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 26:MdcContractSplitStart + SplitStep * 27])
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
                    bytes32(proofData[MdcContractSplitStart + SplitStep * 38:MdcContractSplitStart + SplitStep * 39])
                ) << 128) |
                    uint256(
                        bytes32(
                            proofData[MdcContractSplitStart + SplitStep * 39:MdcContractSplitStart + SplitStep * 40]
                        )
                    )
            ),
            merkle_roots: new bytes32[](3)
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
    }

    function parsePublicInputDest(
        bytes calldata proofData
    ) internal pure returns (HelperLib.PublicInputDataDest memory publicInputDest) {
        // uint256 ProofLength = 384;
        // uint256 SplitStep = 32;
        // uint256 CommitTxSplitStart = ProofLength;
        // uint256 TransactionSplitStart = CommitTxSplitStart + SplitStep * 14; // 384 is proof length, SplitStep*14 is L1 commit tx;
        // uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 14;

        uint256 ProofLength = 384;
        uint256 SplitStep = 32;
        uint256 TransactionSplitStart = ProofLength; // 384 is proof length
        uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 17;
        publicInputDest = HelperLib.PublicInputDataDest({
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
