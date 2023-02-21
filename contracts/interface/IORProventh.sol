// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "../library/Operation.sol";

interface IORProventh {
    function startValidate(bytes calldata validateBytes) external view returns (OperationsLib.Transaction memory);

    function updateUserTreeHash(bytes32 rootHash) external;

    function updateNodeTreeHash(bytes32 rootHash) external;
}
