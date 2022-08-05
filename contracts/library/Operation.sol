// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library Operations {
    /// pairChainInfo
    struct pairChainInfo {
        uint256 supportChain;
        bool isSupportDest;
        //uint256 ebcid;
    }

    struct chainInfo {
        uint256 chainid;
        bytes chainName;
        uint256 batchLimit;
        uint256 maxDisputeTime;
    }

    struct tokenInfo {
        address tokenAddress;
        uint256 tokenPresion;
        bytes tokenName;
    }

    struct txInfo {
        address sourceAddress;
        address destAddress;
        address tokenName;
        address tokenAmount;
        address nonce;
        address gas;
    }

    struct lpInfo {
        uint256 sourceChain;
        uint256 destChain;
        address sourceTAddress;
        address destTAddress;
        uint256 tokenPresion;
        uint256 ebcid;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 gasFee;
        uint256 tradingFee;
        bytes tokenName;
    }

    // function addressToDepostContract(address maker)
    //     public
    //     returns (address depostContract)
    // {
    //     depostContract = address(0);
    // }
}
