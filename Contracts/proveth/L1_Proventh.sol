pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "solidity-rlp/contracts/RLPReader.sol";
import "hardhat/console.sol";

contract L1_Proventh {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    uint8 public constant TX_PROOF_RESULT_PRESENT = 1;
    uint8 public constant TX_PROOF_RESULT_ABSENT = 2;

    struct SignedTransaction {
        uint256 nonce;
        uint256 gasprice;
        uint256 startgas;
        address to;
        uint256 value;
        bytes data;
        uint256 v;
        uint256 r;
        uint256 s;
        bool isContractCreation;
    }

    struct ValidateResult {
        uint8 result; // see TX_PROOF_RESULT_*
        uint256 index;
        uint256 nonce;
        uint256 gasprice;
        uint256 startgas;
        address to; // 20 byte address for "regular" tx,
        // empty for contract creation tx
        uint256 value;
        bytes data;
        uint256 v;
        uint256 r;
        uint256 s;
        bool isContractCreation;
    }

    function testTxInfoHash(
        bytes memory rlpTxInfo,
        bytes[] memory proof,
        bytes[] memory header, // blockHash,txRootHash,raw_rlp
        bytes memory rlpTxIndex
    ) public view returns (ValidateResult memory r) {
        // bytes[] memory mptProof, bytes memory rlpIndex, bytes memory raw
        if (header.length != 3) {
            revert("header is invalid");
        }
        if (proof.length == 0) {
            revert("proof is invaild");
        }

        validateRLPTxInfo(rlpTxInfo, proof);
        bytes32 txRootHash = validateTxRootHash(proof, header);
        validateBlockHash(header);

        bytes memory rlpTx = validateMPTProof(
            txRootHash,
            decodeNibbles(rlpTxIndex, 0),
            proof
        );
        console.log("rlpTx-------------------");
        console.logBytes(rlpTx);

        if (rlpTx.length == 0) {
            //empty node
            r.result = TX_PROOF_RESULT_ABSENT;
            r.index = toUint256(rlpTxIndex);
        } else {
            r.result = TX_PROOF_RESULT_PRESENT;
            SignedTransaction memory t = decodeSignedTx(rlpTx);
            r.index = toUint256(rlpTxIndex);
            r.nonce = t.nonce;
            r.gasprice = t.gasprice;
            r.startgas = t.startgas;
            r.to = t.to;
            r.value = t.value;
            r.data = t.data;
            r.v = t.v;
            r.r = t.r;
            r.s = t.s;
            r.isContractCreation = t.isContractCreation;
        }
    }

    function validateRLPTxInfo(bytes memory rlpTxInfo, bytes[] memory proof)
        internal
        view
    {
        bytes memory proof_last_child = proof[proof.length - 1];

        RLPReader.RLPItem[] memory proof_txinfo_rlp = proof_last_child
            .toRlpItem()
            .toList();

        bytes32 proofTxInfo = keccak256(
            proof_txinfo_rlp[proof_txinfo_rlp.length - 1].toBytes()
        );
        bytes32 TxInfo = keccak256(rlpTxInfo);

        console.log("proofTxInfo ========================");
        console.logBytes32(keccak256(proof_txinfo_rlp[1].toBytes()));
        console.log("TxInfo ========================");
        console.logBytes32(keccak256(rlpTxInfo));
        if (proofTxInfo != TxInfo) {
            revert("TxInfoRLP invalid");
        }
    }

    function validateTxRootHash(bytes[] memory proof, bytes[] memory header)
        internal
        view
        returns (bytes32 rootHash)
    {
        bytes memory proof_first_child = proof[0];
        bytes32 proof_txRootHash = keccak256(proof_first_child);
        console.log("proof_txRootHash =====================");
        console.logBytes32(keccak256(proof_first_child));

        bytes32 header_txRootHash = bytesToBytes32(header[1], 0);
        console.log("header_txRootHash =====================");
        console.logBytes32(header_txRootHash);
        if (proof_txRootHash != header_txRootHash) {
            revert("txRoothash Check invalid");
        }
        rootHash = header_txRootHash;
    }

    function validateBlockHash(bytes[] memory header) internal view {
        bytes32 headerBlockHash = bytesToBytes32(header[0], 0);
        console.log("headerBlockHash =====================");
        console.logBytes32(headerBlockHash);
        bytes32 rawBlockHash = keccak256(header[2]);
        console.log("rawBlockHash =====================");
        console.logBytes32(rawBlockHash);
        if (headerBlockHash != rawBlockHash) {
            revert("blockHash check invaild");
        }
    }

    function validateMPTProof(
        bytes32 rootHash,
        bytes memory mptKey,
        bytes[] memory proof
    ) internal view returns (bytes memory value) {
        uint256 mptKeyOffset = 0;

        bytes32 nodeHashHash;
        bytes memory rlpNode;
        RLPReader.RLPItem[] memory node;

        RLPReader.RLPItem memory rlpValue;
        console.log("proof.length =", proof.length);
        if (proof.length == 0) {
            // Root hash of empty Merkle-Patricia-Trie
            require(
                rootHash ==
                    0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421,
                "rootHash unEqual"
            );
            return new bytes(0);
        }
        // Traverse proof of nodes starting at root.
        for (uint256 i = 0; i < proof.length; i++) {
            // We use the fact that an rlp encoded list consists of some
            // encoding of its length plus the concatenation of its
            // *rlp-encoded* items.
            rlpNode = proof[i];
            if (i == 0 && rootHash != keccak256(rlpNode)) {
                revert("rootHash != keccak256(rlpNode)");
            }
            // ... whereas all other nodes are hashed with the MPT
            // hash function.
            if (i != 0 && nodeHashHash != mptHashHash(rlpNode)) {
                console.log("i =", i);
                console.log("nodeHashHash-----------------------");
                console.logBytes32(nodeHashHash);
                console.log("mptHashHash(rlpNode)-----------------------");
                console.logBytes32(keccak256(rlpNode));
                console.logBytes32(mptHashHash(rlpNode));
                revert("nodeHashHash != mptHashHash(rlpNode)");
            }
            // We verified that proof[i] has the correct hash, so we
            // may safely decode it.
            node = rlpNode.toRlpItem().toList();
            if (node.length == 2) {
                // Extension or Leaf node
                console.log("Node is a ExtensionNode or LeafNode");
                bool isLeaf;
                bytes memory nodeKey;
                // get node true type (isLeaf)
                (isLeaf, nodeKey) = merklePatriciaCompactDecode(
                    node[0].toBytes()
                );
                uint256 prefixLength = sharedPrefixLength(
                    mptKeyOffset,
                    mptKey,
                    nodeKey
                );
                mptKeyOffset += prefixLength;
                if (prefixLength < nodeKey.length) {
                    // Proof claims divergent extension or leaf. (Only
                    // relevant for proofs of exclusion.)
                    // An Extension/Leaf node is divergent iff it "skips" over
                    // the point at which a Branch node should have been had the
                    // excluded key been included in the trie.
                    // Example: Imagine a proof of exclusion for path [1, 4],
                    // where the current node is a Leaf node with
                    // path [1, 3, 3, 7]. For [1, 4] to be included, there
                    // should have been a Branch node at [1] with a child
                    // at 3 and a child at 4.

                    // Sanity check
                    if (i < proof.length - 1) {
                        // divergent node must come last in proof
                        revert();
                    }

                    return new bytes(0);
                }

                if (isLeaf) {
                    console.log("Node is a LeafNode");
                    // Sanity check
                    if (i < proof.length - 1) {
                        // leaf node must come last in proof
                        revert();
                    }

                    if (mptKeyOffset < mptKey.length) {
                        return new bytes(0);
                    }

                    rlpValue = node[1];
                    console.log("LeafNode return");
                    return rlpValue.toBytes();
                } else {
                    // extension
                    // Sanity check
                    if (i == proof.length - 1) {
                        // shouldn't be at last level
                        revert();
                    }

                    if (!node[1].isList()) {
                        // rlp(child) was at least 32 bytes. node[1] contains
                        // Keccak256(rlp(child)).
                        nodeHashHash = keccak256(node[1].toBytes());
                    } else {
                        // rlp(child) was at less than 32 bytes. node[1] contains
                        // rlp(child).
                        nodeHashHash = keccak256(node[1].toRlpBytes());
                    }
                }
            } else if (node.length == 17) {
                // Branch node
                console.log("node is a branchNode");
                if (mptKeyOffset != mptKey.length) {
                    // we haven't consumed the entire path, so we need to look at a child
                    uint8 nibble = uint8(mptKey[mptKeyOffset]);
                    console.log("nibble =", nibble);
                    mptKeyOffset += 1;
                    if (nibble >= 16) {
                        // each element of the path has to be a nibble
                        revert("revert1");
                    }

                    if (isEmptyBytesequence(node[nibble])) {
                        console.log("i =", i);
                        console.log("proof.length - 1 =", proof.length - 1);
                        // Sanity
                        if (i != proof.length - 1) {
                            // leaf node should be at last level
                            revert("revert2");
                        }
                        return new bytes(0);
                    } else if (!node[nibble].isList()) {
                        console.log("node[nibble] != list");
                        nodeHashHash = keccak256(node[nibble].toBytes());
                        console.logBytes32(nodeHashHash);
                    } else {
                        console.log("node[nibble] = list");
                        nodeHashHash = keccak256(node[nibble].toRlpBytes());
                    }
                } else {
                    // we have consumed the entire mptKey, so we need to look at what's contained in this node.
                    // Sanity
                    if (i != proof.length - 1) {
                        // should be at last level
                        revert("revert3");
                    }
                    return node[16].toBytes();
                }
            }
        }
    }

    function bytesToBytes32(bytes memory b, uint256 offset)
        private
        pure
        returns (bytes32)
    {
        bytes32 out;

        for (uint256 i = 0; i < 32; i++) {
            out |= bytes32(b[offset + i] & 0xFF) >> (i * 8);
        }
        return out;
    }

    function toUint256(bytes memory _bytes)
        internal
        pure
        returns (uint256 value)
    {
        assembly {
            value := mload(add(_bytes, 0x20))
        }
    }

    function subbyte(
        bytes memory self,
        uint256 startIndex,
        uint256 len
    ) internal pure returns (bytes memory) {
        require(startIndex <= self.length && self.length - startIndex >= len);
        uint256 addr = dataPtr(self);
        return toBytes(addr + startIndex, len);
    }

    function dataPtr(bytes memory bts) internal pure returns (uint256 addr) {
        assembly {
            addr := add(bts, 32)
        }
    }

    function toBytes(uint256 addr, uint256 len)
        internal
        pure
        returns (bytes memory bts)
    {
        bts = new bytes(len);
        uint256 btsptr;
        assembly {
            btsptr := add(bts, 32)
        }
        copy(addr, btsptr, len);
    }

    //拷贝
    function copy(
        uint256 src,
        uint256 dest,
        uint256 len
    ) internal pure {
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }
        uint256 mask = 256**(32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    function sharedPrefixLength(
        uint256 xsOffset,
        bytes memory xs,
        bytes memory ys
    ) internal pure returns (uint256) {
        uint256 i;
        for (i = 0; i + xsOffset < xs.length && i < ys.length; i++) {
            if (xs[i + xsOffset] != ys[i]) {
                return i;
            }
        }
        return i;
    }

    function isEmptyBytesequence(RLPReader.RLPItem memory item)
        internal
        pure
        returns (bool)
    {
        if (item.len != 1) {
            return false;
        }
        uint8 b;
        uint256 memPtr = item.memPtr;
        assembly {
            b := byte(0, mload(memPtr))
        }
        return b == 0x80; /* empty byte string */
    }

    function merklePatriciaCompactDecode(bytes memory compact)
        internal
        pure
        returns (bool isLeaf, bytes memory nibbles)
    {
        require(compact.length > 0);
        uint256 first_nibble = (uint8(compact[0]) >> 4) & 0xF;
        uint256 skipNibbles;
        if (first_nibble == 0) {
            skipNibbles = 2;
            isLeaf = false;
        } else if (first_nibble == 1) {
            skipNibbles = 1;
            isLeaf = false;
        } else if (first_nibble == 2) {
            skipNibbles = 2;
            isLeaf = true;
        } else if (first_nibble == 3) {
            skipNibbles = 1;
            isLeaf = true;
        } else {
            // Not supposed to happen!
            revert();
        }
        return (isLeaf, decodeNibbles(compact, skipNibbles));
    }

    function mptHashHash(bytes memory input) internal view returns (bytes32) {
        console.log("aaaaaaaaaaaaaaaaaaaaa =", input.length);
        if (input.length < 32) {
            return keccak256(input);
        } else {
            return
                keccak256(abi.encodePacked(keccak256(abi.encodePacked(input))));
        }
    }

    function decodeNibbles(bytes memory compact, uint256 skipNibbles)
        internal
        pure
        returns (bytes memory nibbles)
    {
        require(compact.length > 0);

        uint256 length = compact.length * 2;
        require(skipNibbles <= length);
        length -= skipNibbles;

        nibbles = new bytes(length);
        uint256 nibblesLength = 0;

        for (uint256 i = skipNibbles; i < skipNibbles + length; i += 1) {
            if (i % 2 == 0) {
                nibbles[nibblesLength] = bytes1(
                    (uint8(compact[i / 2]) >> 4) & 0xF
                );
            } else {
                nibbles[nibblesLength] = bytes1(
                    (uint8(compact[i / 2]) >> 0) & 0xF
                );
            }
            nibblesLength += 1;
        }

        assert(nibblesLength == nibbles.length);
    }

    function decodeSignedTx(bytes memory rlpSignedTx)
        internal
        view
        returns (SignedTransaction memory t)
    {
        // 1559 require
        require(rlpSignedTx.length > 1 && rlpSignedTx[0] == 0x02);

        bytes memory rawRlpTx = subbyte(rlpSignedTx, 1, rlpSignedTx.length - 1);

        RLPReader.RLPItem[] memory fields = rawRlpTx.toRlpItem().toList();

        address potentialAddress;
        bool isContractCreation;
        if (isEmpty(fields[5])) {
            potentialAddress = 0x0000000000000000000000000000000000000000;
            isContractCreation = true;
        } else {
            potentialAddress = fields[5].toAddress();
            isContractCreation = false;
        }

        t = SignedTransaction(
            fields[1].toUint(),
            fields[3].toUint(),
            fields[4].toUint(),
            potentialAddress,
            fields[6].toUint(),
            fields[7].toBytes(),
            fields[9].toUint(),
            fields[10].toUint(),
            fields[11].toUint(),
            isContractCreation
        );
    }

    function isEmpty(RLPReader.RLPItem memory item)
        internal
        pure
        returns (bool)
    {
        if (item.len != 1) {
            return false;
        }
        uint8 b;
        uint256 memPtr = item.memPtr;
        assembly {
            b := byte(0, mload(memPtr))
        }
        return
            b == 0x80 || /* empty byte string */
            b == 0xc0; /* empty list */
    }
}
