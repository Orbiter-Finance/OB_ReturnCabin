// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORChallengeSpv} from "../interface/IORChallengeSpv.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {HelperLib} from "../library/HelperLib.sol";

import {Era2MainnetLib} from "../library/Era2MainnetLib.sol";

contract ORChallengeSpvEra2Mainnet is IORChallengeSpv, Ownable {
    using Era2MainnetLib for bytes;
    address private _sourceTxVerifier;
    address private _destTxVerifier;

    constructor(address sourceTxVerifier, address destTxVerifier) {
        _transferOwnership(msg.sender);
        setSpvVerifierAddr(sourceTxVerifier, destTxVerifier);
    }

    function setSpvVerifierAddr(address sourceTxVerifier, address destTxVerifier) public onlyOwner {
        _sourceTxVerifier = sourceTxVerifier;
        _destTxVerifier = destTxVerifier;
    }

    function getSpvVerifierAddr() external view override returns (address, address) {
        return (_sourceTxVerifier, _destTxVerifier);
    }

    function verifySourceTx(bytes calldata zkProof) external returns (bool) {
        (bool success, ) = _sourceTxVerifier.call(zkProof);
        return success && zkProof.checkSourceTxProof();
    }

    function verifyDestTx(bytes calldata zkProof) external returns (bool) {
        (bool success, ) = _destTxVerifier.call(zkProof);
        return success && zkProof.checkDestTxProof();
    }

    function parseSourceTxProof(bytes calldata zkProof) external pure returns (HelperLib.PublicInputDataSource memory) {
        return zkProof.parsePublicInputSource();
    }

    function parseDestTxProof(bytes calldata zkProof) external pure returns (HelperLib.PublicInputDataDest memory) {
        return zkProof.parsePublicInputDest();
    }
}
