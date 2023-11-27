// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {HelperLib} from "../library/HelperLib.sol";

interface IORChallengeSpv {
    struct VerifyInfoSlot {
        address account; // Contract address
        bytes32 key;
        uint256 value;
    }

    struct VerifyInfo {
        uint256[] data;
        VerifyInfoSlot[] slots;
    }

    function verifySourceTx(bytes calldata zkProof) external returns (bool);

    function verifyDestTx(bytes calldata zkProof) external returns (bool);

    function parseSourceTxProof(bytes calldata zkProof) external pure returns (HelperLib.PublicInputDataSource memory);

    function parseDestTxProof(bytes calldata zkProof) external pure returns (HelperLib.PublicInputDataDest memory);
}
