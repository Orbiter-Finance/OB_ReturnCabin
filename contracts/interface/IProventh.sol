// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IProventh {
    struct ValidateParams {
        bytes[] txInfo; // RLP encoding of Raw data for L1 Submission Hash
        bytes[][] proof; // MPT Proof Data for L1 Blocks Containing L1 Submission Hash
        bytes[] blockInfo; // Contains the information of the header part of the L1 block, the RLP encoding of the Raw data of the L1 block, and the data required to trace the L1 block.
        bytes sequence; // The sequence number of L1 Submission Hash in L1 block
    }

    struct SignedTransaction {
        uint256 nonce;
        uint256 gasprice;
        uint256 startgas;
        address to;
        uint256 value;
        bytes data;
        uint256 v;
        uint256 r;
        uint256 s;
        bool isContractCreation;
    }

    struct SignedCustomTransaction {
        bytes txHash;
        bytes blockHash;
        bytes input;
        address from;
        address to;
        uint256 blockNumber;
        uint256 chainId;
        uint256 nonce;
        uint256 gas;
        uint256 gasPrice;
        uint256 value;
        uint256 transactionIndex;
    }

    struct ValidateResult {
        bool result; // see TX_PROOF_RESULT_*
        bytes txHash;
        bytes blockHash;
        bytes input;
        address from;
        address to;
        uint256 blockNumber;
        uint256 chainId;
        uint256 nonce;
        uint256 gas;
        uint256 gasPrice;
        uint256 value;
        uint256 transactionIndex;
        // uint256 chainId; //l2 hash chainId
        // uint256 index;
        // uint256 nonce;
        // uint256 gasprice;
        // uint256 startgas;
        // address to; // 20 byte address for "regular" tx,
        // // empty for contract creation tx
        // uint256 value;
        // bytes data;
        // uint256 v;
        // uint256 r;
        // uint256 s;
        // bool isContractCreation;
    }

    function startValidate(ValidateParams calldata params)
        external
        view
        returns (ValidateResult memory r);

    function updateTreeHash(bytes calldata rootHash) external;
}
