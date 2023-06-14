// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import "../library/Operation.sol";

interface IORProventhMainnet {
    function startValidate(
        bytes calldata srcTx,
        uint256 seqNum,
        bytes32[] calldata storageBlockHash,
        bytes32[] calldata slots
    ) external view returns (OperationsLib.Transaction memory);
}
