// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {HelperLib} from "./library/HelperLib.sol";
import {IORSpvData} from "./interface/IORSpvData.sol";

contract ORSpvData is IORSpvData {
    using HelperLib for bytes;

    address public manager;

    uint64 private _blockInterval = 192;
    address private _injectOwner;
    mapping(bytes32 => uint) private _blocksRoots; // [start ..._blockInterval... end]'s blocks root => startBlockNumber

    constructor(address manager_, address injectOwner_) {
        require(manager_ != address(0), "MZ");
        manager = manager_;

        if (injectOwner_ != address(0)) {
            _injectOwner = injectOwner_;
            emit InjectOwnerUpdated(injectOwner_);
        }
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Forbidden: caller is not the manager");
        _;
    }

    function blockInterval() external view returns (uint64) {
        return _blockInterval;
    }

    function updateBlockInterval(uint64 blockInterval_) external onlyManager {
        require(blockInterval_ >= 2 && blockInterval_ <= 256, "IOF");
        require(blockInterval_ % 2 == 0, "IV");

        _blockInterval = blockInterval_;

        emit BlockIntervalUpdated(blockInterval_);
    }

    function _calculateRoot(uint startBlockNumber) internal view returns (bytes32) {
        uint len = _blockInterval / 2;
        bytes32 root;
        assembly {
            let leaves := mload(0x40)
            mstore(0x40, add(leaves, mul(len, 0x20)))

            // The lowest layer is calculated separately from other layers to save gas
            for {
                let i := 0
                let leavesPtr := leaves
            } lt(i, len) {
                i := add(i, 1)
            } {
                let ix2 := mul(i, 2)
                let data := mload(0x40)
                mstore(data, blockhash(add(startBlockNumber, ix2)))
                mstore(add(data, 0x20), blockhash(add(startBlockNumber, add(ix2, 1))))

                mstore(leavesPtr, keccak256(data, 0x40))

                // Release memory
                data := mload(0x40)

                leavesPtr := add(leavesPtr, 0x20)
            }

            for {

            } gt(len, 1) {
                len := add(div(len, 2), mod(len, 2))
            } {
                for {
                    let i := 0
                    let leavesPtr := leaves
                } lt(i, len) {
                    i := add(i, 2)
                } {
                    // Default
                    let ptrL := add(leaves, mul(i, 0x20))
                    mstore(leavesPtr, mload(ptrL))

                    // When i+1 < len, hash(ptrL connect ptrR)
                    if lt(add(i, 1), len) {
                        let ptrR := add(ptrL, 0x20)

                        let data := mload(0x40)
                        mstore(data, mload(ptrL))
                        mstore(add(data, 0x20), mload(ptrR))

                        mstore(leavesPtr, keccak256(data, 0x40))

                        // Release memory
                        data := mload(0x40)
                    }

                    leavesPtr := add(leavesPtr, 0x20)
                }
            }

            root := mload(leaves)
        }

        return root;
    }

    function saveHistoryBlocksRoots() external {
        uint currentBlockNumber = block.number;
        uint bi = _blockInterval;
        uint startBlockNumber = currentBlockNumber - 256;
        uint batchLen;
        unchecked {
            uint m = startBlockNumber % bi;
            if (m > 0) {
                startBlockNumber += bi - m;
            }

            batchLen = (currentBlockNumber - 1 - startBlockNumber) / bi;
        }

        // Reject when batchLen == 0, save gas
        require(batchLen > 0, "IBL");

        for (uint i = 0; i < batchLen; ) {
            bytes32 root = _calculateRoot(startBlockNumber);

            if (_blocksRoots[root] == 0 && root != bytes32(0)) {
                _blocksRoots[root] = startBlockNumber;
                emit HistoryBlocksRootSaved(startBlockNumber, root, bi);
            }

            unchecked {
                startBlockNumber += bi;
                i++;
            }
        }
    }

    function getStartBlockNumber(bytes32 blocksRoot) external view returns (uint) {
        return _blocksRoots[blocksRoot];
    }

    function injectOwner() external view returns (address) {
        return _injectOwner;
    }

    function updateInjectOwner(address injectOwner_) external onlyManager {
        _injectOwner = injectOwner_;
        emit InjectOwnerUpdated(injectOwner_);
    }

    function injectBlocksRoots(
        bytes32 blocksRoot0,
        bytes32 blocksRoot1,
        InjectionBlocksRoot[] calldata injectionBlocksRoots
    ) external {
        require(msg.sender == _injectOwner, "Forbidden: caller is not the inject owner");

        uint blockNumber0 = _blocksRoots[blocksRoot0];
        uint blockNumber1 = _blocksRoots[blocksRoot1];

        require(blockNumber0 < blockNumber1, "SNLE");

        // Make sure the blockNumber0 and blockNumber1 at storage
        require(blockNumber0 != 0, "SZ");
        require(blockNumber1 != 0, "EZ"); // This logic may never be false

        uint i = 0;
        uint ni = 0;
        for (; i < injectionBlocksRoots.length; ) {
            unchecked {
                ni = i + 1;
            }

            InjectionBlocksRoot memory ibsr = injectionBlocksRoots[i];

            require(blockNumber0 < ibsr.startBlockNumber, "IBLE0");
            require(blockNumber1 > ibsr.startBlockNumber, "IBGE1");
            require(ibsr.startBlockNumber % _blockInterval == 0, "IIB");
            require(_blocksRoots[ibsr.blocksRoot] == 0, "BE");

            _blocksRoots[ibsr.blocksRoot] = ibsr.startBlockNumber;
            emit HistoryBlocksRootSaved(ibsr.startBlockNumber, ibsr.blocksRoot, _blockInterval);

            i = ni;
        }
    }
}
