## How to determine the zkSync's SPV design？

### Event

There is a transaction whose txHash is 0x992ab3dd81fb2c98bfcce69b439ed6f061dce20304003433ede499ac0d5ac1ce, exsists NO. 47434 block in zkSync, which records `TXinfo_0x992A`.

![image-20211224144535536](https://tva1.sinaimg.cn/large/008i3skNly1gxox6z6lhgj31a00o0acp.jpg)

We need to prove it happens in ZkSync on the L1 chain.

It is known that 47434 is committed in L1 to commit tx(0x8da41494671c582825805f6ea7bfe6c05bc4d623573fac3254eef865db0a5668).

The block number is 13852824 in L1 verify tx(0x6eca2e988159690205870d3a5c686494f88317779dbab0d8cd508744fe2d5e75).

The zkSync chain generates new roothash:286b3e6f8e1a168b41d16c859da9a1ba5c69d107bc601abf8b895b47050e90f6.

### Tx life

The trusted RootHash available in the contract looks like this, using this method to get `StoredBlockHashes(47434)` and verify 47434 has been proven.

> https://etherscan.io/address/0xabea9132b05a70803a4e85094fd0e1800777fbef#readProxyContract
>
> > StoredBlockHashes(47434)
> >
> > ![image-20211222142650323](https://tva1.sinaimg.cn/large/008i3skNgy1gxmlesf07uj323c0h2myp.jpg)
>
> > 47434 <= totalBlocksProven
> >
> > ![image-20211222142752081](https://tva1.sinaimg.cn/large/008i3skNly1gxoxj70hwoj323g0620t0.jpg)

We can see the value here : `StoredBlockHashes(47434)` = 0xc5c0fad4bfc9cc5c948c0216312f0765df4399aed4cbf60c21449a4dbc0b5336

The next step is to restore this process: 

```
TX "0x992ab3dd81fb2c98bfcce69b439ed6f061dce20304003433ede499ac0d5ac1ce" 
=> Encode => 
storedBlockHashes " 0xc5c0fad4bfc9cc5c948c0216312f0765df4399aed4cbf60c21449a4dbc0b5336"
```

It means to describe `TXinfo_0x992A`'s life cycle in zkSync, and the data structure of the nodes in this cycle.

We now know three explicit data structures: `TXinfo_0x992A`, `txhash_0x992A`, and `storedBlockHash_47434`.

According to the zkSync's  [commit tx](https://etherscan.io/tx/0x8da41494671c582825805f6ea7bfe6c05bc4d623573fac3254eef865db0a5668)  in L1, we can also get a fourth explicit data structure: `inputData_0x8da4149`.

> ![image-20211222144315148](https://tva1.sinaimg.cn/large/008i3skNly1gxoxtuxkvtj323k076adu.jpg)

The order of data generation is as follows:

`TXinfo_0x992A` => `inputData_0x8da4149`  => `storedBlockHash_47434` 

We don't need `txhash_0x992A`.

**Investigation: `inputData_0x8da4149`  => `storedBlockHash_47434`** 

> ![image-20211222144821355](https://tva1.sinaimg.cn/large/008i3skNly1gxoy3k7dvbj323c0f6dh8.jpg)
>
> ```
> function commitBlocks(StoredBlockInfo memory _lastCommittedBlockData, CommitBlockInfo[] memory _newBlocksData)
> ```

`InputData_0x8da4149` is actually `function_encode + stroreBlockInfo_pre47434 + CommitBlockInfo[]`.

Because commit sends three data at once, `InputData_0x8da4149` needs to capture the `commintBlockInfo_47434` associated with `TXinfo_0x992A` using the above structure.



Check the Github source code. There are two methods to convert `commintBlockInfo_47434` to `storedBlockHashes[47434]` in [CommitBlocks()](https://github.com/matter-labs/zksync/blob/master/contracts/contracts/ZkSync.sol#L394-L415).

> ```
> # 1. convert commintBlockInfo_47434 to StoredBlockInfo_47434
> _lastCommittedBlockData = commitOneBlock(_lastCommittedBlockData, _newBlocksData[i]);
> 
> # 2. convert StoredBlockInfo_47434 to storedBlockHashes[47434]
> storedBlockHashes[_lastCommittedBlockData.blockNumber] = hashStoredBlockInfo(_lastCommittedBlockData);
> ```

Look closer into how  convert`commintBlockInfo_47434` to `StoredBlockInfo_47434`.

> ```
> data structure：
> 
> /// @notice Data needed to commit new block
> struct CommitBlockInfo {
>   bytes32 newStateHash;
>   bytes publicData;    txinfo在这
>   uint256 timestamp;
>   OnchainOperationData[] onchainOperations;
>   uint32 blockNumber;
>   uint32 feeAccount;
> }
> 
> /// @Rollup block stored data
> /// @member blockNumber Rollup block number
> /// @member priorityOperations Number of priority operations processed
> /// @member pendingOnchainOperationsHash Hash of all operations that must be processed after verify
> /// @member timestamp Rollup block timestamp, have the same format as Ethereum block constant
> /// @member stateHash Root hash of the rollup state
> /// @member commitment Verified input for the zkSync circuit
> struct StoredBlockInfo {
>   uint32 blockNumber;
>   uint64 priorityOperations;
>   bytes32 pendingOnchainOperationsHash;
>   uint256 timestamp;
>   bytes32 stateHash;
>   bytes32 commitment;
> }
> 
> method：
> function commitOneBlock(StoredBlockInfo memory _previousBlock, CommitBlockInfo memory _newBlock){
> return
>       StoredBlockInfo(
>           _newBlock.blockNumber,
>           priorityReqCommitted,
>           pendingOnchainOpsHash,
>           _newBlock.timestamp,
>           _newBlock.newStateHash,
>           commitment
>       );
> }
> 
> StoredBlockInfo_47434 = {
> 	commintBlockInfo_47434.blockNumber,
> 	?, 
> 	?,
> 	commintBlockInfo_47434.timestamp,
> 	commintBlockInfo_47434.newStateHash,   // notincludingTX
> 
> }
> 
> 
> bytes32 commitment = createBlockCommitment(_previousBlock, _newBlock, onchainOpsOffsetCommitment);
> 
> 
> ```
>
> Commitment includes publicData
>
> ```
> /// @dev Creates block commitment from its data
> /// @dev _offsetCommitment - hash of the array where 1 is stored in chunk where onchainOperation begins and 0 for other chunks
> function createBlockCommitment(
>   StoredBlockInfo memory _previousBlock,
>   CommitBlockInfo memory _newBlockData,
>   bytes memory _offsetCommitment
> ) internal view returns (bytes32 commitment) {
>   bytes32 hash = sha256(abi.encodePacked(uint256(_newBlockData.blockNumber), uint256(_newBlockData.feeAccount)));
>   hash = sha256(abi.encodePacked(hash, _previousBlock.stateHash));
>   hash = sha256(abi.encodePacked(hash, _newBlockData.newStateHash));
>   hash = sha256(abi.encodePacked(hash, uint256(_newBlockData.timestamp)));
> 
>   bytes memory pubdata = abi.encodePacked(_newBlockData.publicData, _offsetCommitment);
> 
>   /// The code below is equivalent to `commitment = sha256(abi.encodePacked(hash, _publicData))`
> 
>   /// We use inline assembly instead of this concise and readable code in order to avoid copying of `_publicData` (which saves ~90 gas per transfer operation).
> 
>   /// Specifically, we perform the following trick:
>   /// First, replace the first 32 bytes of `_publicData` (where normally its length is stored) with the value of `hash`.
>   /// Then, we call `sha256` precompile passing the `_publicData` pointer and the length of the concatenated byte buffer.
>   /// Finally, we put the `_publicData.length` back to its original location (to the first word of `_publicData`).
>   assembly {
>       let hashResult := mload(0x40)
>       let pubDataLen := mload(pubdata)
>       mstore(pubdata, hash)
>       // staticcall to the sha256 precompile at address 0x2
>       let success := staticcall(gas(), 0x2, pubdata, add(pubDataLen, 0x20), hashResult, 0x20)
>       mstore(pubdata, pubDataLen)
> 
>       // Use "invalid" to make gas estimation work
>       switch success
>       case 0 {
>           invalid()
>       }
> 
>       commitment := mload(hashResult)
>   }
> }
> ```

Look closer into how convert `StoredBlockInfo_47434`to `storedBlockHashes[47434]`.

>```
>function hashStoredBlockInfo(StoredBlockInfo memory _storedBlockInfo) internal pure returns (bytes32) {
>return keccak256(abi.encode(_storedBlockInfo));
>}
>```

##### Investigation：TXinfo_0x992A => inputData_0x8da4149

> According to the above investigation, we know that `TXinfo` took the following path:：`txinfo` => `pubdata`  => `commintBlockInfo_47434` => `commintBlockInfos[]` => `commit tx input`

Key investigation：`txinfo` => `pubdata`

There is a definition of "rollup" in the zkSync system and a definition of data structures in the [ProtocalDoc]((https://github.com/matter-labs/zksync/blob/master/docs/protocol.md#example-1)).

> 1. Transfer
>
> ![image-20211222174649562](https://tva1.sinaimg.cn/large/008i3skNly1gxoyw2dindj31fl0u0tc2.jpg)
>
>
> 2. Transfer to new
>
> ![image-20211222174758102](https://tva1.sinaimg.cn/large/008i3skNly1gxoyw3x0j7j318l0u0wiq.jpg)
>
> ![image-20211222175037274](https://tva1.sinaimg.cn/large/008i3skNly1gxoyw1xi1lj31lc09c40c.jpg)

Rollup at `TXinfo_0x992A` .

opcode = 0x05  

> In this case, from and to in `TXinfo_0x992A` are both new accounts, and the op type belongs to transfer.

from_acount = 790468 =>  000c0fc4

> Follow this link to get the ID.
>
> https://api.zksync.io/api/v0.2/accounts/0x2347b1b2b8cd9ee89ce4fa8c12f05bf65eb123e7

token = 0 => 00000000

> https://api.zksync.io/api/v0.2/tokens/ETH

to_account = 719541 => 000afab5

> https://api.zksync.io/api/v0.2/accounts/0xbd5f7f276d94afcac1505f93a98c0ec39a6e6a23

Packed_amount = 0.002376 => ?

Packed_fee = 0.0000668 => ?



Final result：0x05000c0fc400000000000afab5xxxxxxxxxxxxxx

It was found in `inputData` of [[commit tx]](https://etherscan.io/tx/0x8da41494671c582825805f6ea7bfe6c05bc4d623573fac3254eef865db0a5668).

![image-20211222185606215](https://tva1.sinaimg.cn/large/008i3skNly1gxoyw3bn9cj31jk05yn0s.jpg)



Note: The forgery of Pubdata should be considered in the scheme design.



**How does `Txinfo.from`（0x2347b1b2b8cd9ee89ce4fa8c12f05bf65eb123e7）correspond on-chain to `from_acount (000C0FC4)` and `to_acount`.**

`storedBlockHash_47434.stateHash` is composed of sparse Merkle trees, and the raw data is:

> https://api.zksync.io/api/v0.2/blocks/47434
>
> newStateRoot = 286b3e6f8e1a168b41d16c859da9a1ba5c69d107bc601abf8b895b47050e90f6
>
> proof：newstateRoot + "otherdata" ==  storedBlockHash_47434 

Suppose we have rebuilt the blockdata of the blockdata structure under StateRoot from the input data of the mainnet through zkSync's blockchain client and written a method which is acount_info = getBlockdata[key]. In that case, we can get the following proof path:

> 1. acount_info_000c0fc4.address ==  0x2347b1b2b8cd9ee89ce4fa8c12f05bf65eb123e7
>
> 2. proof(Hash(rpc(acount_info_000c0fc4)) + "MPT_Proof") = newStateRoot

##### Rebuild the blockdata of the blockdata structure under StateRoot from the input data of the mainnet through zkSync's blockchain client.

> https://github.com/matter-labs/zksync/blob/master/docs/architecture.md
>
> ![zksync](/Users/h/Desktop/zksync.png)
>
> https://github.com/matter-labs/zksync/tree/master/core/bin/data_restore/src
>
> ![image-20211222230654541](https://tva1.sinaimg.cn/large/008i3skNly1gxoyw48k28j31r10u0aey.jpg)
>
> Run it and rebuild the database from the database.





### Proof scheme

##### the first proof route of proof

> `storedBlockHashs[47434]` is used as the comparison hash.
>
> Pros： Low gas fee and 1 million gas limit.
>
> Cons： It isn't universal enough to be an SPV solution for all rollups.

1. TXinfo_0x992A => x => pubdata_47434

2. pubdata  + "otherDataHash" => commitment   ''Note: Reuse createBlockCommitment() method， only need to rewrite it in part."

3. commitment + "otherDataHash" => toredBlockHash_47434



##### the second  proof route of proof

> L1's `blockhash_aboutZksync47434Commit` is used as the comparison hash.
>
> Pros: It is universal enough to be an SPV solution for all rollups.
>
> Cons: High gas fee and 2 million gas limit."**Note**: Starkware's Cairo code can overwrite it to put calculations off-chain."

1. TXinfo_0x992A => x => inputdata_L1TX_0x992ab3dd

2. inputdata_L1TX_0x992ab3dd + "otherData" => L1TX_0x992ab3dd 

3. L1TX_0x992ab3dd  + MPT_proof => L1blockhash_13852824

4. L1blockhash_13852824 + "otherProof" => L1blockhash_nowBlockNumber

   > The below  step is required because the blockhash(uint blockNumber) method only fetches Roothash from the current block to the 256th block in about an hour.
   >
   > `block.blockhash(uint blockNumber) returns (bytes32)`: hash of the given block - only works for 256 most recent, excluding current, blocks - deprecated in version 0.4.22 and replaced by `blockhash(uint blockNumber)`.



All left is how to code, and Orbiter is on its way.

