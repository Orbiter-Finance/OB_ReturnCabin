// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IVerifierRouter {
    function verify(bytes calldata zkProof, uint256 instanceBytesLength) external view returns (bool);
}
