// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;
import "solidity-rlp/contracts/RLPReader.sol";
import {NotEmptyRootHash, NotEqualNodeValue} from "./Error.sol";

bytes32 constant EmptyRootHash = 0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421;

library MerkleLib {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    function _efficientHash(bytes memory i) internal pure returns (bytes32 value) {
        assembly {
            value := keccak256(add(i, 0x20), mload(i))
        }
    }

    function _efficientDoubleHash(bytes memory i) internal pure returns (bytes32 value) {
        assembly {
            let y := keccak256(add(i, 0x20), mload(i))
            mstore(0x00, y)
            value := keccak256(0x00, 0x20)
        }
    }

    function decodeNibbles(bytes memory compact, uint256 skipNibbles) internal pure returns (bytes memory nibbles) {
        require(compact.length > 0);

        uint256 length = compact.length * 2;
        require(skipNibbles <= length);
        length -= skipNibbles;

        nibbles = new bytes(length);
        uint256 nibblesLength = 0;
        uint256 itemLength = skipNibbles + length;
        unchecked {
            for (uint256 i = skipNibbles; i < itemLength; ++i) {
                if (i % 2 == 0) {
                    nibbles[nibblesLength] = bytes1((uint8(compact[i / 2]) >> 4) & 0xF);
                } else {
                    nibbles[nibblesLength] = bytes1((uint8(compact[i / 2]) >> 0) & 0xF);
                }

                ++nibblesLength;
            }
        }

        if (nibblesLength != nibbles.length) {
            revert();
        }
    }

    function mptHashHash(bytes memory input) internal pure returns (bytes32 x) {
        if (input.length < 32) {
            x = keccak256(input);
        } else {
            return _efficientDoubleHash(input);
        }
    }

    function verifyProof(
        bytes32 rootHash,
        bytes memory mptKey,
        bytes[] memory proof
    ) internal pure returns (bytes memory value) {
        uint256 mptKeyOffset = 0;
        uint256 proofLength = proof.length;
        bytes32 nodeHashHash;
        bytes memory rlpNode;
        RLPReader.RLPItem[] memory node;
        RLPReader.RLPItem memory rlpValue;
        unchecked {
            if (proofLength == 0) {
                // Root hash of empty Merkle-Patricia-Trie
                if (rootHash != EmptyRootHash) {
                    revert NotEmptyRootHash();
                }
                return new bytes(0);
            } else {
                // Traverse proof of nodes starting at root.
                for (uint256 i = 0; i < proofLength; ++i) {
                    // We use the fact that an rlp encoded list consists of some
                    // encoding of its length plus the concatenation of its
                    // *rlp-encoded* items.
                    rlpNode = proof[i];
                    if (i == 0 && rootHash != keccak256(rlpNode)) {
                        revert NotEqualNodeValue();
                    }
                    // ... whereas all other nodes are hashed with the MPT
                    // hash function.
                    if (i != 0 && nodeHashHash != mptHashHash(rlpNode)) {
                        revert NotEqualNodeValue();
                    }
                    // We verified that proof[i] has the correct hash, so we
                    // may safely decode it.
                    node = rlpNode.toRlpItem().toList();
                    if (node.length == 2) {
                        // Extension or Leaf node
                        bool isLeaf;
                        bytes memory nodeKey;
                        // get node true type (isLeaf)
                        (isLeaf, nodeKey) = merklePatriciaCompactDecode(node[0].toBytes());
                        uint256 prefixLength = sharedPrefixLength(mptKeyOffset, mptKey, nodeKey);
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
                            if (i < proofLength - 1) {
                                // divergent node must come last in proof
                                revert();
                            }

                            return new bytes(0);
                        }

                        if (isLeaf) {
                            // Sanity check
                            if (i < proofLength - 1) {
                                // leaf node must come last in proof
                                revert();
                            }

                            if (mptKeyOffset < mptKey.length) {
                                return new bytes(0);
                            }

                            rlpValue = node[1];
                            return rlpValue.toBytes();
                        } else {
                            // extension
                            // Sanity check
                            if (i == proofLength - 1) {
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
                        if (mptKeyOffset != mptKey.length) {
                            // we haven't consumed the entire path, so we need to look at a child
                            uint8 nibble = uint8(mptKey[mptKeyOffset]);
                            ++mptKeyOffset;
                            if (nibble >= 16) {
                                // each element of the path has to be a nibble
                                revert("revert1");
                            }

                            if (isEmptyBytesequence(node[nibble])) {
                                // Sanity
                                if (i != proofLength - 1) {
                                    // leaf node should be at last level
                                    revert("revert2");
                                }
                                return new bytes(0);
                            } else if (!node[nibble].isList()) {
                                nodeHashHash = keccak256(node[nibble].toBytes());
                            } else {
                                nodeHashHash = keccak256(node[nibble].toRlpBytes());
                            }
                        } else {
                            // we have consumed the entire mptKey, so we need to look at what's contained in this node.
                            // Sanity
                            if (i != proofLength - 1) {
                                // should be at last level
                                revert("revert3");
                            }
                            return node[16].toBytes();
                        }
                    }
                }
            }
        }
    }

    function isEmptyBytesequence(RLPReader.RLPItem memory item) internal pure returns (bool) {
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

    function sharedPrefixLength(
        uint256 xsOffset,
        bytes memory xs,
        bytes memory ys
    ) internal pure returns (uint256) {
        uint256 i;
        unchecked {
            for (i = 0; i + xsOffset < xs.length && i < ys.length; ++i) {
                if (xs[i + xsOffset] != ys[i]) {
                    return i;
                }
            }
        }
        return i;
    }
}
