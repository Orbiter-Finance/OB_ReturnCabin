// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "../library/Operation.sol";

interface IORProventh {
    struct ValidateParams {
        bytes[] txInfo; // RLP encoding of Raw data for L1 Submission Hash
        bytes[][] proof; // MPT Proof Data for L1 Blocks Containing L1 Submission Hash
        bytes[] blockInfo; // Contains the information of the header part of the L1 block, the RLP encoding of the Raw data of the L1 block, and the data required to trace the L1 block.
        bytes[] sequence; // The sequence number of L1 Submission Hash in L1 block
    }

    function startValidate(bytes calldata validateBytes) external view returns (OperationsLib.Transaction memory);

    function updateUserTreeHash(bytes32 rootHash) external;

    function updateNodeTreeHash(bytes32 rootHash) external;
}
