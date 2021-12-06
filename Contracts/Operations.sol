// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
import "hardhat/console.sol";

library Operations {

  /// txInfo
    struct TxInfo {
        address from;
        address to;
        address tokenAddress;
        uint256 timestamp;
        uint256 amount;
        uint256 nonce;
    }

    struct PoolExt {
        uint256 tradingFee;
        uint256 gasFee;
        uint256 avalibleDeposit;
        uint256 onemin;
        uint256 onemax;
        address protocal;
    }

    struct LPInfo {
        address makerAddress;
        uint256 fromChainID;
        uint256 toChainID;
        address fromTokenAddress;
        address toTokenAddress;
        address contractTokenAddress;
        uint256 avalibleETH;
        uint256 changExtKey;
        bool canStart;
        uint256[] avalibleTimes;
    }

    struct chainInfo {
        uint256 chainid;
        uint256 batchLimit;
        uint256 maxDisputeTime;
    }

    function addressToDepostContract(address maker)
        public
        returns (address depostContract)
    {
        depostContract = address(0);
    }
}
