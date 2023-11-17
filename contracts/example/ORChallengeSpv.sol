// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORChallengeSpv} from "../interface/IORChallengeSpv.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ORChallengeSpv is IORChallengeSpv, Ownable {
    address public sourceTxVerifier;
    address public destTxVerifier;

    function setSpvVerifierAddr(address _sourceTxVerifier, address _destTxVerifier) public onlyOwner {
        sourceTxVerifier = _sourceTxVerifier;
        destTxVerifier = _destTxVerifier;
    }

    constructor(address _sourceTxVerifier, address _destTxVerifier) {
        _transferOwnership(msg.sender);
        setSpvVerifierAddr(_sourceTxVerifier, _destTxVerifier);
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
