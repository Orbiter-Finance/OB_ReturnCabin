// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library Types {
    struct ChainInfo {
        uint8 id;
        uint16 batchLimit;
        mapping(uint => TokenInfo) tokens;
    }

    struct TokenInfo {
        uint256 tokenAddress;
        uint8 decimals;
        address layer1Token;
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
        bytes data;
    }
    struct Pair {
        uint8 s;
        uint8 d;
        uint256 sToken;
        uint256 dToken;
    }
    struct PairConfig {
        uint8 state; // 0 = stop,1=start,2=pause
        uint256 tradingFee;
        uint256 withholdingFee;
        uint256 minPrice;
        uint256 maxPrice;
        // uint pledgeAmount;
    }
  
}
