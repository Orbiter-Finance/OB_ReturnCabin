// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {HelperLib} from "../library/HelperLib.sol";

interface IORChallengeSpv {
    function setSpvVerifierAddr(address sourceTxVerifier, address destTxVerifier) external;

    function getSpvVerifierAddr() external view returns (address, address);

    function verifySourceTx(bytes calldata zkProof) external returns (bool);

    function verifyDestTx(bytes calldata zkProof) external returns (bool);

    function parseSourceTxProof(bytes calldata zkProof) external pure returns (HelperLib.PublicInputDataSource memory);

    function parseDestTxProof(bytes calldata zkProof) external pure returns (HelperLib.PublicInputDataDest memory);
}
