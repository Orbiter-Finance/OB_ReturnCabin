// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library OperationsLib {
    /// pairChainInfo
    struct pairChainInfo {
        uint256 sourceChain;
        uint256 destChain;
        address sourceTAddress;
        address destTAddress;
        uint256 ebcid;
    }

    struct tokenInfo {
        uint256 chainID;
        address tokenAddress;
        uint256 tokenPresion;
        address mainTokenAddress;
    }

    struct chainInfo {
        uint256 chainid;
        uint256 batchLimit;
        uint256 maxDisputeTime;
        address[] tokenList;
        bool isUsed;
    }

    struct txInfo {
        uint256 chainID;
        bytes32 txHash;
        bytes32 lpid;
        address sourceAddress;
        address destAddress;
        address tokenAddress;
        uint256 amount;
        uint256 nonce;
        uint256 timestamp;
        bytes32 responseHash;
    }

    struct lpInfo {
        uint256 sourceChain;
        uint256 destChain;
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

    struct lpPairInfo {
        bytes32 LPRootHash;
        uint256 stopTime;
        uint256 startTime;
        bool inlps;
    }

    struct chainDeposit {
        address tokenAddress; // mainNetTokenAddress
        uint256 depositAmount;
        uint256 useLimit; //
        bytes32[] lpids;
    }

    struct chanllengeInfo {
        uint256 chanllengeState; // 0:unused   1:watting for maker  2.maker success   3.maker failed   4.ma
        bytes32 responseTxinfo;
        uint256 stopTime;
        uint256 endTime;
        uint256 pledgeAmount;
        uint256 ebcid;
    }

    function getLpID(pairChainInfo memory _lpinfo) internal pure returns (bytes32) {
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

    function getLpFullHash(OperationsLib.lpInfo memory _lpinfo) internal pure returns (bytes32) {
        bytes32 lpId = getLpID(_lpinfo);
        bytes32 rootHash = keccak256(
            abi.encodePacked(
                lpId,
                _lpinfo.ebcid,
                _lpinfo.sourcePresion,
                _lpinfo.destPresion,
                _lpinfo.minPrice,
                _lpinfo.maxPrice,
                _lpinfo.gasFee,
                _lpinfo.tradingFee
            )
        );
        return rootHash;
    }

    function getLpID(lpInfo memory _lpinfo) internal pure returns (bytes32) {
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

    function getChanllengeID(txInfo memory _txinfo) internal pure returns (bytes32) {
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
