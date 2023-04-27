import "./RLPWriter.sol";
import "./Type.sol";

library Helper {
    using RLPWriter for uint256;
    using RLPWriter for address;
    using RLPWriter for bytes;
    using RLPWriter for bytes[];

    function recoverSigner(Types.TransactionEIP1559 calldata tx) public pure returns (address signer) {
        bytes memory encode;
        bytes[] memory encodeList = new bytes[](9);
        encodeList[0] = abi.encodePacked(tx.chainId.writeUint());
        encodeList[1] = abi.encodePacked(tx.nonce.writeUint());
        encodeList[2] = abi.encodePacked(tx.maxPriorityFeePerGas.writeUint());
        encodeList[3] = abi.encodePacked(tx.maxFeePerGas.writeUint());
        encodeList[4] = abi.encodePacked(tx.gasLimit.writeUint());
        encodeList[5] = abi.encodePacked(tx.to.writeAddress());
        encodeList[6] = abi.encodePacked(tx.value.writeUint());
        encodeList[7] = abi.encodePacked(tx.data.writeBytes());
        encodeList[8] = abi.encodePacked(tx.accessList.writeList());
        encode = encodeList.writeList();
        encode = abi.encodePacked(bytes1(0x02), encode);
        bytes32 hashMessage = keccak256(encode);

        // Recover the signer address from the signature
        signer = ecrecover(hashMessage, uint8(tx.v + 27), bytes32(tx.r), bytes32(tx.s));
    }
    
}
