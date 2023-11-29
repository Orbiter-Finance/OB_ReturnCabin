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

    struct PublicInputDataSource {
        bytes32 tx_hash;
        uint64 chain_id;
        uint256 index;
        uint256 from;
        uint256 to;
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
