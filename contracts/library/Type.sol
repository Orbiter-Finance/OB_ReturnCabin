// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library Types {
    struct ChainInfo {
        uint256 id;
        uint256 batchLimit;
        mapping(address => TokenInfo) tokens;
    }

    struct TokenInfo {
        uint256 precision;
        address tokenAddress;
        address mainAddress;
    }
    struct TransactionEIP1559 {
        uint chainId;
        uint nonce;
        uint maxPriorityFeePerGas;
        uint maxFeePerGas;
        uint gasLimit;
        address to;
        uint value;
        bytes data;
        bytes[] accessList;
        uint v;
        bytes32 r;
        bytes32 s;
    }
    struct Transaction {
        address from;
        address to;
        address tokenAddress;
        bytes32 txHash;
        bytes32 blockHash;
        uint256 blockNumber;
        uint256 chainId;
        uint256 nonce;
        uint256 gas;
        uint256 gasPrice;
        uint256 value;
        uint256 transactionIndex;
        uint256 timeStamp;
    }
}
