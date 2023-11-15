// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

abstract contract VerifierLogicAbstract {
    function verifyPartial(
        uint256[] memory pubInputs,
        bytes memory proof,
        bool success,
        bytes32[1033] memory transcript
    ) public view virtual returns (bool, bytes32[1033] memory);
}