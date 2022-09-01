// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "../library/Operation.sol";

interface IORSpv {
    function setUserTxTreeRoot(uint256 chain, bytes32 root) external;

    function setMakerTxTreeRoot(uint256 chain, bytes32 root) external;

    function verifyUserTxProof(OperationsLib.txInfo memory _txInfo, bytes32[] calldata _proof)
        external
        view
        returns (bool);

    function verifyMakerTxProof(OperationsLib.txInfo memory _txInfo, bytes32[] calldata _proof)
        external
        view
        returns (bool);
}
