// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORChallengeSpv} from "../interface/IORChallengeSpv.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {HelperLib} from "../library/HelperLib.sol";

contract ORChallengeSpv is IORChallengeSpv, Ownable {
    using HelperLib for bytes;
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
        uint256 ProofLength = 384;
        uint256 SplitStep = 32;
        uint256 TransactionSplitStart = ProofLength + 64; // 384 is proof length;64 is blockHash length
        uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 12;
        bool merkleRootMatch = ((uint256(bytes32(zkProof[TrackBlockSplitStart:TrackBlockSplitStart + SplitStep])) <<
            128) | uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep:TrackBlockSplitStart + SplitStep * 2]))) ==
            ((uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 8:TrackBlockSplitStart + SplitStep * 9])) <<
                128) |
                uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 9:TrackBlockSplitStart + SplitStep * 10])));

        (bool success, ) = sourceTxVerifier.call(zkProof);
        return success && merkleRootMatch;
    }

    function verifyDestTx(bytes calldata zkProof) external returns (bool) {
        uint256 ProofLength = 384;
        uint256 SplitStep = 32;
        uint256 CommitTxSplitStart = ProofLength;
        uint256 TransactionSplitStart = CommitTxSplitStart + SplitStep * 14; // 384 is proof length, SplitStep*14 is L1 commit tx;
        uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 14;
        bool merkleRootMatch = ((uint256(bytes32(zkProof[CommitTxSplitStart:CommitTxSplitStart + SplitStep])) << 128) |
            uint256(bytes32(zkProof[CommitTxSplitStart + SplitStep:CommitTxSplitStart + SplitStep * 2]))) ==
            ((uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 2:TrackBlockSplitStart + SplitStep * 3])) <<
                128) |
                uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 3:TrackBlockSplitStart + SplitStep * 4])));

        (bool success, ) = destTxVerifier.call(zkProof);
        return success;
    }

    function parseSourceTxProof(bytes calldata zkProof) external pure returns (HelperLib.PublicInputDataSource memory) {
        return zkProof.parsePublicInputSource();
    }

    function parseDestTxProof(bytes calldata zkProof) external pure returns (HelperLib.PublicInputDataDest memory) {
        return zkProof.parsePublicInputDest();
    }
}
