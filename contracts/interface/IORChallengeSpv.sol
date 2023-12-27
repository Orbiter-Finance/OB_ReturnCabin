// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PublicInputParseLib} from "../library/ChallengeSpvLib.sol";

interface IORChallengeSpv {
    function setSpvVerifierAddr(address sourceTxVerifier, address destTxVerifier) external;

    function getSpvVerifierAddr() external view returns (address, address);

    function verifySourceTx(bytes calldata zkProof) external returns (bool);

    function verifyDestTx(bytes calldata zkProof) external returns (bool);

    function parseSourceTxProof(
        bytes calldata zkProof
    ) external pure returns (PublicInputParseLib.PublicInputDataSource memory);

    function parseDestTxProof(
        bytes calldata zkProof
    ) external pure returns (PublicInputParseLib.PublicInputDataDest memory);
}
