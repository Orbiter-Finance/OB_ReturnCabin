// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;
import "./../interfaces/IOrbiterExtrator.sol";





contract OrbiterExtrator_L1 is  IOrbiterExtrator{

    mapping (uint=>Operations.TxInfo) verifyMap;
    Operations.TxInfo[]  txinfoArray;

    address MAKER_ADDRESS = address(0x000);
    address USER_ADDRESS = address(0x000);

    // verifyMap{
    //   t1: txinfo1
    //   t2: txinfo2
    //   t3: txinfo3
    //   t4: txinfo4
    // }

    constructor(address tokenAddress) public {
      Operations.TxInfo memory fromInfo = Operations.TxInfo (
        MAKER_ADDRESS,
        USER_ADDRESS,
        tokenAddress,
        block.timestamp + 10000,
        10009001,
        13
      );
      Operations.TxInfo memory toInfo = Operations.TxInfo (
        USER_ADDRESS,
        MAKER_ADDRESS,
        tokenAddress,
        block.timestamp + 11000,
        3980013,
        1
      );
      verifyMap[0] = fromInfo;
      verifyMap[1] = toInfo;
    }

    function getVerifiedTx (
        uint txid
    ) external override returns (Operations.TxInfo memory abc){
        abc = verifyMap[txid];
    }
}