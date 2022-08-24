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
        uint256 startTime;
    }

    struct lpPairInfo {
        bytes32 LPRootHash;
        uint256 stopTime;
        uint256 startTime;
    }

    struct chainDeposit {
        address tokenAddress; // mainNetTokenAddress
        uint256 depositAmount;
        uint256 useLimit; //
    }

    struct chanllengeInfo {
        uint256 chanllengeState; // 0:unused   1:watting for maker  2.maker success   3.maker failed   4.ma
        bytes32 responseTxinfo;
        uint256 startTime;
        uint256 endTime;
        uint256 pledgeAmount;
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
                _lpinfo.tokenName,
                _lpinfo.tokenPresion,
                _lpinfo.ebcid,
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
    // function addressToDepostContract(address maker)
    //     public
    //     returns (address depostContract)
    // {
    //     depostContract = address(0);
    // }
}
