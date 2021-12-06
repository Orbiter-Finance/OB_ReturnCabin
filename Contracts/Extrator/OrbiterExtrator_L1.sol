// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;
import "./../interfaces/IOrbiterExtrator.sol";


contract OrbiterExtrator_L1 is  IOrbiterExtrator{

    mapping (uint=>Operations.TxInfo) verifyMap;
    Operations.TxInfo[]  txinfoArray;
    
    // verifyMap{
    //   t1: txinfo1
    //   t2: txinfo2
    //   t3: txinfo3
    //   t4: txinfo4
    // }

    function getVerifiedTx (
        uint txid
    ) external override returns (Operations.TxInfo calldata abc){
        abc = verifyMap[txid];
    }
}