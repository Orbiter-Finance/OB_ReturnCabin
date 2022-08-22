// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "../library/Spv.sol";

interface IORSpv {
    function setUserTxTreeRoot(uint256 chain, bytes32 root) external;

    function setMakerTxTreeRoot(uint256 chain, bytes32 root) external;

    function verifyUserTxProof(SpvLib.Transaction memory _txInfo, bytes32[] calldata _proofs)
        external
        view
        returns (bool);

    function verifyMakerTxProof(SpvLib.Transaction memory _txInfo, bytes32[] calldata _proofs)
        external
        view
        returns (bool);
}
