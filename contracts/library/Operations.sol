// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import "./TransactionLib.sol";

library OperationsLib {
    struct EBCConfigStruct {
        uint challengePledgedAmount;
        uint16 pledgeAmountSafeRate;
        uint16 mainCoinPunishRate;
        uint16 tokenPunishRate;
    }
    struct CalculatePairPledgeResponse {
        bytes32 pairId;
        address pledgedToken;
        uint maxPrice;
        uint pledgedValue;
    }
    struct CalculatePairPledgeResponseTemp {
        address pledgedToken;
        uint chainId;
        uint pledgedValue;
    }

    struct TokenInfo {
        uint8 decimals;
        uint token; // uint160(address) will overflow in the token used for starknet
        address mainnetToken;
    }

    struct ChainInfo {
        uint id;
        uint batchLimit;
        address[] spvs;
        uint minVerifyChallengeSourceTxSecond;
        uint maxVerifyChallengeSourceTxSecond;
        uint minVerifyChallengeDestTxSecond;
        uint maxVerifyChallengeDestTxSecond;
        TokenInfo[] tokens;
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
        uint blockNumber;
        uint chainId;
        uint nonce;
        uint gas;
        uint gasPrice;
        uint value;
        uint transactionIndex;
        uint timeStamp;
    }
    struct PairStruct {
        uint ebcId;
        uint sourceChain;
        uint destChain;
        address sourceToken;
        address destToken;
    }
    struct LPActionStruct {
        bytes32 pairId;
        uint minPrice;
        uint maxPrice;
        uint gasFee;
        uint tradingFee;
    }
    struct LPUpdateStruct {
        bytes32 pairId;
        uint gasFee;
        uint tradingFee;
    }
    struct EffectivePairStruct {
        bytes32 lpId;
        uint startTime;
        uint stopTime;
    }
    struct LPStruct {
        bytes32 pairId;
        uint minPrice;
        uint maxPrice;
        uint gasFee;
        uint tradingFee;
        uint startTime;
        uint stopTime;
    }
    struct lpInfo {
        address sourceToken;
        address destToken;
        uint sourceChain;
        uint destChain;
        address ebc;
        uint sourcePresion;
        uint destPresion;
        uint minPrice;
        uint maxPrice;
        uint gasFee;
        uint tradingFee;
        uint startTime;
    }

    struct challengeInfo {
        uint challengeState; // 0:unused   1:watting for maker  2.maker success   3.maker failed   4.ma
        uint stopTime;
        uint endTime;
        uint value;
        uint pledged;
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
        uint startTime,
        uint minPrice,
        uint maxPrice
    ) internal pure returns (bytes32) {
        // bytes32 pairId = getPairID(_lpinfo);
        bytes32 rootHash = keccak256(abi.encodePacked(pairId, makerId, startTime, minPrice, maxPrice));
        return rootHash;
    }

    function getChallengeID(Transaction memory _txinfo) internal pure returns (bytes32) {
        // get to chainId
        return keccak256(abi.encodePacked(_txinfo.chainId, _txinfo.from, _txinfo.to, _txinfo.value, _txinfo.nonce));
    }

    function uintToString(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function stringToUint(string memory s) internal pure returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint i = 0; i < b.length; i++) {
            uint c = uint(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }
}
