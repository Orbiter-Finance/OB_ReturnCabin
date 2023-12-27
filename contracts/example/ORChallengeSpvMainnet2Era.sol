// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IORChallengeSpv} from "../interface/IORChallengeSpv.sol";
import {Mainnet2EraLib, PublicInputParseLib} from "../library/ChallengeSpvLib.sol";

contract ORChallengeSpvMainnet2Era is IORChallengeSpv, Ownable {
    using Mainnet2EraLib for bytes;
    using PublicInputParseLib for bytes;
    address private _sourceTxVerifier;
    address private _destTxVerifier;

    constructor(address sourceTxVerifier, address destTxVerifier) {
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

    function parseSourceTxProof(
        bytes calldata zkProof
    ) external pure returns (PublicInputParseLib.PublicInputDataSource memory) {
        return zkProof.parsePublicInputSource();
    }

    function parseDestTxProof(
        bytes calldata zkProof
    ) external pure returns (PublicInputParseLib.PublicInputDataDest memory) {
        return zkProof.parsePublicInputDest();
    }
}
