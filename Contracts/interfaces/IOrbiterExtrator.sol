// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;
import "./../Operations.sol";


interface IOrbiterExtrator {
    function getVerifiedTx (
        uint txid
    ) external returns (Operations.TxInfo calldata abc);

    function getVerifiedNoHappenTx (
        uint txid
    ) external returns (Operations.TxInfo calldata abc, uint t1, uint t2);
}