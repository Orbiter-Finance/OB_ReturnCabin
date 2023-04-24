// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import "./TransactionLib.sol";

library OperationsLib {
    struct EBCConfigStruct {
        uint256 challengePledgedAmount;
        uint16 pledgeAmountSafeRate;
        uint16 mainCoinPunishRate;
        uint16 tokenPunishRate;
    }
    struct CalculatePairPledgeResponse {
        bytes32 pairId;
        address pledgedToken;
        uint256 maxPrice;
        uint256 pledgedValue;
    }
    struct CalculatePairPledgeResponseTemp {
        address pledgedToken;
        uint256 chainId;
        uint256 pledgedValue;
    }

    struct TokenInfo {
        uint256 chainID;
        uint8 decimals;
        address tokenAddress;
        address mainTokenAddress;
    }

    struct ChainInfo {
        uint256 id;
        uint256 batchLimit;
        uint256 maxDisputeTime;
        uint256 maxReceiptTime;
        uint256 stopDelayTime;
        uint256 maxBits;
    }
    struct TransactionEIP1559Struct {
        uint chainId;
        uint nonce;
        uint maxPriorityFeePerGas;
        uint maxFeePerGas;
        uint gasLimit;
        address to;
        uint value;
        bytes data;
        bytes [] accessList;
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
    struct PairStruct {
        uint256 ebcId;
        uint256 sourceChain;
        uint256 destChain;
        address sourceToken;
        address destToken;
    }
    struct LPActionStruct {
        bytes32 pairId;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 gasFee;
        uint256 tradingFee;
    }
    struct LPUpdateStruct {
        bytes32 pairId;
        uint256 gasFee;
        uint256 tradingFee;
    }
    struct EffectivePairStruct {
        bytes32 lpId;
        uint256 startTime;
        uint256 stopTime;
    }
    struct LPStruct {
        bytes32 pairId;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 gasFee;
        uint256 tradingFee;
        uint256 startTime;
        uint256 stopTime;
    }
    struct lpInfo {
        address sourceToken;
        address destToken;
        uint256 sourceChain;
        uint256 destChain;
        address ebc;
        uint256 sourcePresion;
        uint256 destPresion;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 gasFee;
        uint256 tradingFee;
        uint256 startTime;
    }

    struct challengeInfo {
        uint256 challengeState; // 0:unused   1:watting for maker  2.maker success   3.maker failed   4.ma
        uint256 stopTime;
        uint256 endTime;
        uint256 value;
        uint256 pledged;
        address ebc;
        address token;
        bytes32 responseTxinfo;
    }

    struct ProventhParams {
        TransactionLib.TxInfo txInfo; // RLP encoding of Raw data for L1 Submission Hash
        bytes[][] proof; // MPT Proof Data for L1 Blocks Containing L1 Submission Hash
        TransactionLib.BlockInfo blockInfo; // Contains the information of the header part of the L1 block, the RLP encoding of the Raw data of the L1 block, and the data required to trace the L1 block.
    }

    function getPairID(PairStruct memory pair) internal pure returns (bytes32) {
        return
            keccak256(abi.encodePacked(pair.ebcId, pair.sourceChain, pair.destChain, pair.sourceToken, pair.destToken));
    }

    function getPairID(lpInfo memory _lpinfo) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _lpinfo.sourceChain,
                    _lpinfo.destChain,
                    _lpinfo.sourceToken,
                    _lpinfo.destToken,
                    _lpinfo.ebc
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

    function getChallengeID(Transaction memory _txinfo) internal pure returns (bytes32) {
        // get to chainId
        return keccak256(abi.encodePacked(_txinfo.chainId, _txinfo.from, _txinfo.to, _txinfo.value, _txinfo.nonce));
    }

    function uintToString(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }
}
