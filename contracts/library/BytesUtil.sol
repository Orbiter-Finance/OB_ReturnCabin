// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

library BytesUtil {
    // function decodeBytes(bytes memory b)
    //     internal
    //     pure
    //     returns (ValidateParams memory params)
    // {
    //     RLPReader.RLPItem[] memory decodeItem = b.toRlpItem().toList();
    //     require(decodeItem.length == 4);
    //     unchecked {
    //         for (uint256 index = 0; index < decodeItem.length; ++index) {
    //             if (index == 0) {
    //                 RLPReader.RLPItem[] memory txInfoItem = decodeItem[index]
    //                     .toList();
    //                 uint256 itemLength = txInfoItem.length;
    //                 bytes[] memory txInfo = new bytes[](itemLength);
    //                 for (
    //                     uint256 txInfoIndex = 0;
    //                     txInfoIndex < itemLength;
    //                     ++txInfoIndex
    //                 ) {
    //                     txInfo[txInfoIndex] = txInfoItem[txInfoIndex].toBytes();
    //                 }
    //                 params.txInfo = txInfo;
    //             } else if (index == 1) {
    //                 RLPReader.RLPItem[] memory proofItem = decodeItem[index]
    //                     .toList();
    //                 uint256 itemLength = proofItem.length;
    //                 bytes[][] memory proof = new bytes[][](itemLength);
    //                 for (
    //                     uint256 proofItemIndex = 0;
    //                     proofItemIndex < itemLength;
    //                     ++proofItemIndex
    //                 ) {
    //                     RLPReader.RLPItem[] memory proofDetailItem = proofItem[
    //                         proofItemIndex
    //                     ].toList();
    //                     uint256 itemLength = proofDetailItem.length;
    //                     bytes[] memory proofDetail = new bytes[](itemLength);
    //                     for (
    //                         uint256 proofDetailIndex = 0;
    //                         proofDetailIndex < itemLength;
    //                         ++proofDetailIndex
    //                     ) {
    //                         proofDetail[proofDetailIndex] = proofDetailItem[
    //                             proofDetailIndex
    //                         ].toBytes();
    //                     }
    //                     proof[proofItemIndex] = proofDetail;
    //                 }
    //                 params.proof = proof;
    //             } else if (index == 2) {
    //                 RLPReader.RLPItem[] memory blockItem = decodeItem[index]
    //                     .toList();
    //                 uint256 itemLength = blockItem.length;
    //                 bytes[] memory blocks = new bytes[](itemLength);
    //                 for (
    //                     uint256 blockItemIndex = 0;
    //                     blockItemIndex < itemLength;
    //                     ++blockItemIndex
    //                 ) {
    //                     blocks[blockItemIndex] = blockItem[blockItemIndex]
    //                         .toBytes();
    //                 }
    //                 params.blockInfo = blocks;
    //             } else if (index == 3) {
    //                 RLPReader.RLPItem[] memory seqItem = decodeItem[index]
    //                     .toList();
    //                 uint256 itemLength = seqItem.length;
    //                 bytes[] memory seq = new bytes[](itemLength);
    //                 for (
    //                     uint256 seqItemIndex = 0;
    //                     seqItemIndex < itemLength;
    //                     ++seqItemIndex
    //                 ) {
    //                     seq[seqItemIndex] = seqItem[seqItemIndex].toBytes();
    //                 }
    //                 params.sequence = seq;
    //             }
    //         }
    //     }
    // }

    function contains(bytes memory wholeBytes, bytes memory isExistBytes)
        internal
        pure
        returns (bool)
    {
        require(
            wholeBytes.length >= isExistBytes.length,
            "isExistBytes length not range"
        );

        bool found = false;
        for (uint256 i = 0; i <= wholeBytes.length - isExistBytes.length; ) {
            bool flag = true;
            for (uint256 j = 0; j < isExistBytes.length; j++)
                if (wholeBytes[i + j] != isExistBytes[j]) {
                    flag = false;
                    break;
                }
            if (flag) {
                found = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        return found;
    }
}
