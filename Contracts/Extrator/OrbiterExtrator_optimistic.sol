// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IOrbiterExtrator.sol';

contract OrbiterExtrator_optimistic is IOrbiterExtrator {

    address public immutable override trustedRoot;
    mapping(int24 => TxInfo) public override checkedTxs;

    constructor(address _trustedRoot) {
        trustedRoot = _trustedRoot
    }

    function checkProofIsHappen () {


        // id

        // checkedTxs[id] = sss
    }

    function checkProofIsNotHappen () {

        return true;
    }

    function getVerifiedTx (uint256 id) {
        return txinfo[id];
    }

    function generateId (TxInfo txInfo) returns (uint256 id) {
        return 0;
    }
}

