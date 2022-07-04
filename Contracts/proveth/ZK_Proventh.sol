// pragma solidity ^0.5.0;
// pragma experimental ABIEncoderV2;

// import "solidity-rlp/contracts/RLPReader.sol";
// import "hardhat/console.sol";

// contract ZK_Proventh {
//     struct StoredBlockInfo {
//         uint32 blockNumber;
//         uint64 priorityOperations;
//         bytes32 pendingOnchainOperationsHash;
//         uint256 timestamp;
//         bytes32 stateHash;
//         bytes32 commitment;
//     }
//     struct CommitBlockInfo {
//         bytes32 newStateHash;
//         bytes publicData;
//         uint256 timestamp;
//         OnchainOperationData[] onchainOperations;
//         uint32 blockNumber;
//         uint32 feeAccount;
//     }

//     function commitBlocks(
//         StoredBlockInfo memory _lastCommittedBlockData,
//         CommitBlockInfo[] memory _newBlocksData
//     ) external nonReentrant {
//         requireActive();
//         governance.requireActiveValidator(msg.sender);
//         // Check that we commit blocks after last committed block
//         require(
//             storedBlockHashes[totalBlocksCommitted] ==
//                 hashStoredBlockInfo(_lastCommittedBlockData),
//             "i"
//         ); // incorrect previous block data

//         for (uint32 i = 0; i < _newBlocksData.length; ++i) {
//             _lastCommittedBlockData = commitOneBlock(
//                 _lastCommittedBlockData,
//                 _newBlocksData[i]
//             );

//             totalCommittedPriorityRequests += _lastCommittedBlockData
//                 .priorityOperations;
//             storedBlockHashes[
//                 _lastCommittedBlockData.blockNumber
//             ] = hashStoredBlockInfo(_lastCommittedBlockData);

//             // emit BlockCommit(_lastCommittedBlockData.blockNumber);
//         }

//         totalBlocksCommitted += uint32(_newBlocksData.length);

//         require(
//             totalCommittedPriorityRequests <= totalOpenPriorityRequests,
//             "j"
//         );
//     }

//     /// @dev Process one block commit using previous block StoredBlockInfo,
//     /// @dev returns new block StoredBlockInfo
//     /// @dev NOTE: Does not change storage (except events, so we can't mark it view)
//     function commitOneBlock(
//         StoredBlockInfo memory _previousBlock,
//         CommitBlockInfo memory _newBlock
//     ) internal view returns (StoredBlockInfo memory storedNewBlock) {
//         require(_newBlock.blockNumber == _previousBlock.blockNumber + 1, "f"); // only commit next block

//         // Check timestamp of the new block
//         {
//             require(_newBlock.timestamp >= _previousBlock.timestamp, "g"); // Block should be after previous block
//             bool timestampNotTooSmall = block.timestamp.sub(
//                 COMMIT_TIMESTAMP_NOT_OLDER
//             ) <= _newBlock.timestamp;
//             bool timestampNotTooBig = _newBlock.timestamp <=
//                 block.timestamp.add(COMMIT_TIMESTAMP_APPROXIMATION_DELTA);
//             require(timestampNotTooSmall && timestampNotTooBig, "h"); // New block timestamp is not valid
//         }

//         // Check onchain operations
//         (
//             bytes32 pendingOnchainOpsHash,
//             uint64 priorityReqCommitted,
//             bytes memory onchainOpsOffsetCommitment
//         ) = collectOnchainOps(_newBlock);

//         // Create block commitment for verification proof
//         bytes32 commitment = createBlockCommitment(
//             _previousBlock,
//             _newBlock,
//             onchainOpsOffsetCommitment
//         );

//         return
//             StoredBlockInfo(
//                 _newBlock.blockNumber,
//                 priorityReqCommitted,
//                 pendingOnchainOpsHash,
//                 _newBlock.timestamp,
//                 _newBlock.newStateHash,
//                 commitment
//             );
//     }

//     /// @dev Creates block commitment from its data
//     /// @dev _offsetCommitment - hash of the array where 1 is stored in chunk where onchainOperation begins and 0 for other chunks
//     function createBlockCommitment(
//         StoredBlockInfo memory _previousBlock,
//         CommitBlockInfo memory _newBlockData,
//         bytes memory _offsetCommitment
//     ) internal view returns (bytes32 commitment) {
//         bytes32 hash = sha256(
//             abi.encodePacked(
//                 uint256(_newBlockData.blockNumber),
//                 uint256(_newBlockData.feeAccount)
//             )
//         );
//         hash = sha256(abi.encodePacked(hash, _previousBlock.stateHash));
//         hash = sha256(abi.encodePacked(hash, _newBlockData.newStateHash));
//         hash = sha256(abi.encodePacked(hash, uint256(_newBlockData.timestamp)));

//         bytes memory pubdata = abi.encodePacked(
//             _newBlockData.publicData,
//             _offsetCommitment
//         );

//         /// The code below is equivalent to `commitment = sha256(abi.encodePacked(hash, _publicData))`

//         /// We use inline assembly instead of this concise and readable code in order to avoid copying of `_publicData` (which saves ~90 gas per transfer operation).

//         /// Specifically, we perform the following trick:
//         /// First, replace the first 32 bytes of `_publicData` (where normally its length is stored) with the value of `hash`.
//         /// Then, we call `sha256` precompile passing the `_publicData` pointer and the length of the concatenated byte buffer.
//         /// Finally, we put the `_publicData.length` back to its original location (to the first word of `_publicData`).
//         assembly {
//             let hashResult := mload(0x40)
//             let pubDataLen := mload(pubdata)
//             mstore(pubdata, hash)
//             // staticcall to the sha256 precompile at address 0x2
//             let success := staticcall(
//                 gas(),
//                 0x2,
//                 pubdata,
//                 add(pubDataLen, 0x20),
//                 hashResult,
//                 0x20
//             )
//             mstore(pubdata, pubDataLen)

//             // Use "invalid" to make gas estimation work
//             switch success
//             case 0 {
//                 invalid()
//             }

//             commitment := mload(hashResult)
//         }
//     }

//     /// @dev Gets operations packed in bytes array. Unpacks it and stores onchain operations.
//     /// @dev Priority operations must be committed in the same order as they are in the priority queue.
//     /// @dev NOTE: does not change storage! (only emits events)
//     /// @dev processableOperationsHash - hash of the all operations that needs to be executed  (Deposit, Exits, ChangPubKey)
//     /// @dev priorityOperationsProcessed - number of priority operations processed in this block (Deposits, FullExits)
//     /// @dev offsetsCommitment - array where 1 is stored in chunk where onchainOperation begins and other are 0 (used in commitments)
//     function collectOnchainOps(CommitBlockInfo memory _newBlockData)
//         internal
//         view
//         returns (
//             bytes32 processableOperationsHash,
//             uint64 priorityOperationsProcessed,
//             bytes memory offsetsCommitment
//         )
//     {
//         bytes memory pubData = _newBlockData.publicData;

//         uint64 uncommittedPriorityRequestsOffset = firstPriorityRequestId +
//             totalCommittedPriorityRequests;
//         priorityOperationsProcessed = 0;
//         processableOperationsHash = EMPTY_STRING_KECCAK;

//         require(pubData.length % CHUNK_BYTES == 0, "A"); // pubdata length must be a multiple of CHUNK_BYTES
//         offsetsCommitment = new bytes(pubData.length / CHUNK_BYTES);
//         for (uint256 i = 0; i < _newBlockData.onchainOperations.length; ++i) {
//             OnchainOperationData memory onchainOpData = _newBlockData
//                 .onchainOperations[i];

//             uint256 pubdataOffset = onchainOpData.publicDataOffset;
//             require(pubdataOffset < pubData.length, "A1");
//             require(pubdataOffset % CHUNK_BYTES == 0, "B"); // offsets should be on chunks boundaries
//             uint256 chunkId = pubdataOffset / CHUNK_BYTES;
//             require(offsetsCommitment[chunkId] == 0x00, "C"); // offset commitment should be empty
//             offsetsCommitment[chunkId] = bytes1(0x01);

//             Operations.OpType opType = Operations.OpType(
//                 uint8(pubData[pubdataOffset])
//             );

//             if (opType == Operations.OpType.Deposit) {
//                 bytes memory opPubData = Bytes.slice(
//                     pubData,
//                     pubdataOffset,
//                     DEPOSIT_BYTES
//                 );

//                 Operations.Deposit memory depositData = Operations
//                     .readDepositPubdata(opPubData);

//                 checkPriorityOperation(
//                     depositData,
//                     uncommittedPriorityRequestsOffset +
//                         priorityOperationsProcessed
//                 );
//                 priorityOperationsProcessed++;
//             } else if (opType == Operations.OpType.ChangePubKey) {
//                 bytes memory opPubData = Bytes.slice(
//                     pubData,
//                     pubdataOffset,
//                     CHANGE_PUBKEY_BYTES
//                 );

//                 Operations.ChangePubKey memory op = Operations
//                     .readChangePubKeyPubdata(opPubData);

//                 if (onchainOpData.ethWitness.length != 0) {
//                     bool valid = verifyChangePubkey(
//                         onchainOpData.ethWitness,
//                         op
//                     );
//                     require(valid, "D"); // failed to verify change pubkey hash signature
//                 } else {
//                     bool valid = authFacts[op.owner][op.nonce] ==
//                         keccak256(abi.encodePacked(op.pubKeyHash));
//                     require(valid, "E"); // new pub key hash is not authenticated properly
//                 }
//             } else {
//                 bytes memory opPubData;

//                 if (opType == Operations.OpType.PartialExit) {
//                     opPubData = Bytes.slice(
//                         pubData,
//                         pubdataOffset,
//                         PARTIAL_EXIT_BYTES
//                     );
//                 } else if (opType == Operations.OpType.ForcedExit) {
//                     opPubData = Bytes.slice(
//                         pubData,
//                         pubdataOffset,
//                         FORCED_EXIT_BYTES
//                     );
//                 } else if (opType == Operations.OpType.WithdrawNFT) {
//                     opPubData = Bytes.slice(
//                         pubData,
//                         pubdataOffset,
//                         WITHDRAW_NFT_BYTES
//                     );
//                 } else if (opType == Operations.OpType.FullExit) {
//                     opPubData = Bytes.slice(
//                         pubData,
//                         pubdataOffset,
//                         FULL_EXIT_BYTES
//                     );

//                     Operations.FullExit memory fullExitData = Operations
//                         .readFullExitPubdata(opPubData);

//                     checkPriorityOperation(
//                         fullExitData,
//                         uncommittedPriorityRequestsOffset +
//                             priorityOperationsProcessed
//                     );
//                     priorityOperationsProcessed++;
//                 } else {
//                     revert("F"); // unsupported op
//                 }

//                 processableOperationsHash = Utils.concatHash(
//                     processableOperationsHash,
//                     opPubData
//                 );
//             }
//         }
//     }

//     function hashStoredBlockInfo(StoredBlockInfo memory _storedBlockInfo)
//         internal
//         pure
//         returns (bytes32)
//     {
//         return keccak256(abi.encode(_storedBlockInfo));
//     }
// }
