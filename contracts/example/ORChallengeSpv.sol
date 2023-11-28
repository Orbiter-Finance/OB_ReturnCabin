// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IORChallengeSpv} from "../interface/IORChallengeSpv.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {HelperLib} from "../library/HelperLib.sol";

import {Mainnet2EraLib} from "../library/Mainnet2EraLib.sol";

contract ORChallengeSpv is IORChallengeSpv, Ownable {
    using Mainnet2EraLib for bytes;
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
        uint256 ProofLength = 384;
        uint256 SplitStep = 32;
        uint256 TransactionSplitStart = ProofLength;
        uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 14;
        uint256 MdcContractSplitStart = TrackBlockSplitStart + SplitStep * 12;
        uint256 original_tx_block_hash = ((uint256(
            bytes32(zkProof[TransactionSplitStart:TransactionSplitStart + SplitStep])
        ) << 128) | uint256(bytes32(zkProof[TransactionSplitStart + SplitStep:TransactionSplitStart + SplitStep * 2])));
        uint256 original_tx_batch_target_block_hash = ((uint256(
            bytes32(zkProof[TrackBlockSplitStart + SplitStep * 2:TrackBlockSplitStart + SplitStep * 3])
        ) << 128) |
            uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 3:TrackBlockSplitStart + SplitStep * 4])));

        uint256 ob_contracts_current_block_hash = (uint256(
            bytes32(zkProof[MdcContractSplitStart + SplitStep * 40:MdcContractSplitStart + SplitStep * 41])
        ) << 128) |
            uint256(bytes32(zkProof[MdcContractSplitStart + SplitStep * 41:MdcContractSplitStart + SplitStep * 42]));

        uint256 ob_contracts_current_batch_target_block_hash = (uint256(
            bytes32(zkProof[TrackBlockSplitStart + SplitStep * 6:TrackBlockSplitStart + SplitStep * 7])
        ) << 128) |
            uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 7:TrackBlockSplitStart + SplitStep * 8]));

        uint256 ob_contracts_next_block_hash = (uint256(
            bytes32(zkProof[MdcContractSplitStart + SplitStep * 42:MdcContractSplitStart + SplitStep * 43])
        ) << 128) |
            uint256(bytes32(zkProof[MdcContractSplitStart + SplitStep * 43:MdcContractSplitStart + SplitStep * 44]));
        uint256 ob_contracts_next_batch_target_block_hash = (uint256(
            bytes32(zkProof[TrackBlockSplitStart + SplitStep * 10:TrackBlockSplitStart + SplitStep * 11])
        ) << 128) |
            uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 11:TrackBlockSplitStart + SplitStep * 12]));

        bool proofMatch = original_tx_block_hash == original_tx_batch_target_block_hash &&
            ob_contracts_current_block_hash == ob_contracts_current_batch_target_block_hash &&
            ob_contracts_next_block_hash == ob_contracts_next_batch_target_block_hash;
        (bool success, ) = _sourceTxVerifier.call(zkProof);
        return success && proofMatch;
    }

    function verifyDestTx(bytes calldata zkProof) external returns (bool) {
        uint256 ProofLength = 384;
        uint256 SplitStep = 32;
        uint256 CommitTxSplitStart = ProofLength;
        uint256 TransactionSplitStart = CommitTxSplitStart + SplitStep * 14;
        uint256 TrackBlockSplitStart = TransactionSplitStart + SplitStep * 14;
        bool proofMatch = ((uint256(bytes32(zkProof[CommitTxSplitStart:CommitTxSplitStart + SplitStep])) << 128) |
            uint256(bytes32(zkProof[CommitTxSplitStart + SplitStep:CommitTxSplitStart + SplitStep * 2]))) ==
            ((uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 2:TrackBlockSplitStart + SplitStep * 3])) <<
                128) |
                uint256(bytes32(zkProof[TrackBlockSplitStart + SplitStep * 3:TrackBlockSplitStart + SplitStep * 4])));

        (bool success, ) = _destTxVerifier.call(zkProof);
        return success && proofMatch;
    }

    function parseSourceTxProof(bytes calldata zkProof) external pure returns (HelperLib.PublicInputDataSource memory) {
        return zkProof.parsePublicInputSource();
    }

    function parseDestTxProof(bytes calldata zkProof) external pure returns (HelperLib.PublicInputDataDest memory) {
        return zkProof.parsePublicInputDest();
    }
}
