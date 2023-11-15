// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORChallengeSpv} from "../interface/IORChallengeSpv.sol";
import {IVerifierRouter} from "../zkp/IVerifierRouter.sol";

// use bellow variables to verify zkProof in .sol spv contract.
uint256 constant INSTANCE_BYTES_LENGTH_MAINNET = 2739;
uint256 constant INSTANCE_BYTES_LENGTH_GOERLI = 2976;
uint256 constant INSTANCE_BYTES_LENGTH_ERA = 330;

contract ORChallengeSpv is IORChallengeSpv {
    address public sourceTxVerifier;
    address public destTxVerifier;

    constructor(address _sourceTxVerifier, address _destTxVerifier) {
        sourceTxVerifier = _sourceTxVerifier;
        destTxVerifier = _destTxVerifier;
    }

    function verifySourceTx(bytes calldata zkProof, uint64 chainId) external view returns (bool) {
        uint256 instanceBytesLength;
        if (chainId == 1) {
            instanceBytesLength = INSTANCE_BYTES_LENGTH_MAINNET;
        } else if (chainId == 5) {
            instanceBytesLength = INSTANCE_BYTES_LENGTH_GOERLI;
        } else if (chainId == 100) {
            instanceBytesLength = INSTANCE_BYTES_LENGTH_ERA;
        } else {
            revert("chainId not support");
        }

        return (IVerifierRouter(sourceTxVerifier).verify(zkProof, instanceBytesLength));
    }

    function verifyDestTx(bytes calldata zkProof) external returns (bool) {
        (bool success, ) = destTxVerifier.call(zkProof);
        return success;
    }
}
