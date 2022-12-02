// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library OperationsLib {
    struct lpPledgeCalculate {
        uint16 chainId;
        uint256 baseValue;
        uint256 additiveValue;
        uint256 pledged;
        uint256 pledgeValue;
    }
    struct calcLpNeedPledgeAmountParams {
        bytes32 pairId;
        uint16 fromChain;
        address fromToken;
        uint256 ebcId;
        uint256 maxPrice;
    }
    struct pairChainInfo {
        uint16 sourceChain;
        uint16 destChain;
        address sourceTAddress;
        address destTAddress;
        uint256 ebcid;
    }

    struct tokenInfo {
        uint16 chainID;
        address tokenAddress;
        uint8 decimals;
        address mainTokenAddress;
    }

    struct chainInfo {
        uint16 chainid;
        uint256 batchLimit;
        uint256 maxDisputeTime;
        uint256 maxReceiptTime;
        uint256 stopDelayTime;
        address[] tokenList;
        bool isUsed;
    }

    struct txInfo {
        uint16 chainID;
        bytes32 txHash;
        bytes32 lpid;
        address sourceAddress;
        address destAddress;
        address tokenAddress;
        uint256 amount;
        uint256 nonce;
        uint256 timestamp;
        uint256 responseAmount;
        uint256 responseSafetyCode;
        uint256 ebcid;
    }

    struct lpInfo {
        uint16 sourceChain;
        uint16 destChain;
        address sourceTAddress;
        address destTAddress;
        uint256 sourcePresion;
        uint256 destPresion;
        uint256 ebcid;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 gasFee;
        uint256 tradingFee;
        uint256 startTime;
    }
    struct lpRestart {
        bytes32 pid;
        bytes32 lpid;
        uint256 gasFee;
        uint256 tradingFee;
    }

    struct lpPairInfo {
        bytes32 lpId;
        uint256 stopTime;
        uint256 startTime;
    }

    struct challengeInfo {
        uint256 challengeState; // 0:unused   1:watting for maker  2.maker success   3.maker failed   4.ma
        bytes32 responseTxinfo;
        uint256 stopTime;
        uint256 endTime;
        address token;
        uint256 value;
        uint256 pledged;
        uint256 ebcid;
    }

    function getPairID(pairChainInfo memory _lpinfo) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _lpinfo.sourceChain,
                    _lpinfo.destChain,
                    _lpinfo.sourceTAddress,
                    _lpinfo.destTAddress,
                    _lpinfo.ebcid
                )
            );
    }

    function getPairID(lpInfo memory _lpinfo) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _lpinfo.sourceChain,
                    _lpinfo.destChain,
                    _lpinfo.sourceTAddress,
                    _lpinfo.destTAddress,
                    _lpinfo.ebcid
                )
            );
    }

    function getLpID(
        bytes32 pairId,
        address makerId,
        uint256 startTime,
        uint256 minPrice,
        uint256 maxPrice
    ) internal pure returns (bytes32) {
        // bytes32 pairId = getPairID(_lpinfo);
        bytes32 rootHash = keccak256(abi.encodePacked(pairId, makerId, startTime, minPrice, maxPrice));
        return rootHash;
    }

    function getChallengeID(txInfo memory _txinfo) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _txinfo.lpid,
                    _txinfo.sourceAddress,
                    _txinfo.destAddress,
                    _txinfo.amount,
                    _txinfo.nonce
                )
            );
    }

    // function addressToDepostContract(address maker)
    //     public
    //     returns (address depostContract)
    // {
    //     depostContract = address(0);
    // }
}
