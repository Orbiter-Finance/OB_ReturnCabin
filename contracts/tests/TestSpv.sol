// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract testSpv {
    address public v_address;

    constructor(address verifier) {
        v_address = verifier;
    }

    function set_v(address _v) public {
        v_address = _v;
    }

    function parseProofData(
        bytes calldata proofData
    )
        external
        pure
        returns (bytes memory _proof, bytes32 blockHash, bytes32 toAddress, uint256 transferAmount, uint256 timestamp)
    {
        _proof = proofData[0:384];
        blockHash = bytes32((uint256(bytes32(proofData[384:416])) << 128) | uint256(bytes32(proofData[416:448])));
        toAddress = bytes32(uint256(bytes32(proofData[448:480])));
        transferAmount = uint256(bytes32(proofData[480:512]));
        timestamp = uint256(bytes32(proofData[512:544]));
    }

    function verifyProof(bytes calldata input) external returns (bool) {
        require(v_address != address(0));
        (bool success, ) = v_address.call(input);
        require(success, "verify fail");
        return success;
    }
}
