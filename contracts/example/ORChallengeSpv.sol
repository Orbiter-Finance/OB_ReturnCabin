// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORChallengeSpv} from "../interface/IORChallengeSpv.sol";

contract ORChallengeSpv is IORChallengeSpv {
    address public sourceTxVerifier;
    address public destTxVerifier;

    constructor(address _sourceTxVerifier, address _destTxVerifier) {
        sourceTxVerifier = _sourceTxVerifier;
        destTxVerifier = _destTxVerifier;
    }

    function verifySourceTx(bytes calldata zkProof) external returns (bool) {
        (bool success, ) = sourceTxVerifier.call(zkProof);
        return success;
    }

    function verifyDestTx(bytes calldata zkProof) external returns (bool) {
        (bool success, ) = destTxVerifier.call(zkProof);
        return success;
    }
}
