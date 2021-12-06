// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import "hardhat/console.sol";
import "./interfaces/IOrbiterExtrator.sol";
import "./interfaces/IOrbiterMakerDeposit.sol";
import "./interfaces/IOrbiterProtocal.sol";
import "./Operations.sol";
import "./interfaces/IOrbiterFactory.sol";

contract OrbiterProtocalV1 is IOrbiterProtocal {

    address managerAddress;
    mapping (uint256 => address) extractorAddressMap;


    constructor(address _managerAddress) {
      managerAddress = _managerAddress;
      console.log("Deploying a OrbiterProtocalV1 with OrbiterProtocalV1");
    }



    // function testMatch(uint256 chainID,uint256 amount) public returns (bool) {
    //   console.logBytes(bytes(chainID));
    //   console.logBytes(bytes(amount));

    //   // bytes memory b = new bytes(32);
    //   // assembly { mstore(add(b, 32), chainID) }
    //   // bytes memory c = new bytes(32);
    //   // assembly { mstore(add(c, 32), amount) }
    //   // console.logBytes32(b);
    //   // console.logBytes32(c);
    //   return true;
    // }

    function isSupportChainID(uint256 chainID)
        override
        public
        returns (bool isSupport)
    {
        Operations.chainInfo memory chainInfo = IOrbiterFactory(managerAddress).getChainInfo(chainID);
        if (chainInfo.chainid != 0) {
          return true;
        }
        return false;
    }

    function getDeposit(uint256 chainid, uint256 oneMax)
        external
        override
        returns (uint256 depositAmount)
    {
        require(oneMax > 0, "oneMax must be greater than 0");
        Operations.chainInfo memory chainInfo = IOrbiterFactory(managerAddress).getChainInfo(chainid);
        require(chainInfo.chainid != 0,"must have chaininfo");
        uint256 batchLimit = chainInfo.batchLimit;
        uint256 oneMaxDeposit = getTokenPunish(oneMax);
        uint256 depositAmount = batchLimit * oneMaxDeposit;
        require(depositAmount > oneMax, "depositAmount must be greater than oneMax");
        return depositAmount;
    }

    function getTokenPunish(uint256 amount)
        override
        public
        view
        returns (uint256 punishAmount)
    {
        uint256 punishNum = 100;
        uint256 punishAmount = amount + amount * punishNum / 100;
        require(punishAmount > amount, "punishAmount must be greater than amount");
        return punishAmount;
    }

    function getETHPunish(uint256 fromChainID)
        external
        override
        view
        returns (uint256 punishETH)
    {
    }

    function getTxInfo(uint256 chainID,uint256 txIndex)
        override
        public
        returns (Operations.TxInfo memory txinfo)
    {
        address extractorAddress = extractorAddressMap[chainID];
        require(extractorAddress != address(0),"extractorAddress can not be address(0)");
        IOrbiterExtrator extractor = IOrbiterExtrator(extractorAddress);
        Operations.TxInfo memory txinfo = extractor.getVerifiedTx(txIndex);
        return txinfo;
    }

    function getDisputeTimeTime(uint256 chainID)
        external
        override
        returns (uint256 disputeTime)
    {
        Operations.chainInfo memory chainInfo = IOrbiterFactory(managerAddress).getChainInfo(chainID);
        require(chainInfo.chainid != 0,"must have chaininfo");
        uint256 disputeTime = chainInfo.maxDisputeTime;
        return disputeTime;
    }

    function getStartDealyTime(uint256 chainID) override external view returns (uint256) {
      uint256 delayTime = 100;
      return delayTime;
    }

    function getStopDealyTime(uint256 chainID) override external view returns (uint256) {
      uint256 delayTime = 100;
      return delayTime;
    }

    function checkUserChallenge(uint256 fromChainID,uint256 TxIndex,uint256 extIndex,uint256 toChainID, Operations.LPInfo memory lpinfo, Operations.PoolExt memory ext) override public returns(bool isSuccess) {
      Operations.TxInfo memory txinfo = getTxInfo(fromChainID,TxIndex);
      require(txinfo.from == msg.sender, 'owner user');
      // require(txinfo.to == makerAddress, 'makerAddress');
      require(extIndex <= lpinfo.avalibleTimes.length / 2, 'extIndex must be legitimate');

      uint256 pText = 9000 + toChainID;
      // ========
      uint256 txTimeStamp = txinfo.timestamp;
      uint256 startTime = lpinfo.avalibleTimes[2 * extIndex];
      uint256 endTime = lpinfo.avalibleTimes[2 * extIndex + 1];
      if (txTimeStamp >= startTime && txTimeStamp <= endTime) {
        return true;
      } else {
        return false;
      }
      if (txinfo.amount > ext.onemin && txinfo.amount <= ext.onemax) {
        return true;
      } else {
        return false;
      }
    }

    function checkMakerChallenge(uint256 fromChainID,uint256 fromTxIndex,uint256 extIndex,uint256 toChainID,uint256 toTxIndex,Operations.LPInfo memory lpinfo) override public returns(bool isSuccess) {
      Operations.TxInfo memory userTxinfo = getTxInfo(fromChainID,fromTxIndex);
      Operations.TxInfo memory makerTxinfo = getTxInfo(toChainID,toTxIndex);

      require(userTxinfo.from == makerTxinfo.to, '1');
      require(userTxinfo.to == makerTxinfo.from, '2');
      require(extIndex <= lpinfo.avalibleTimes.length / 2, 'extIndex must be legitimate');
      uint256 pText = 9000 + toChainID;

      //
      return true;
    }

    function userChanllengeWithDraw(uint256 fromChainID,uint256 TxIndex,uint256 extIndex,uint256 toChainID, Operations.LPInfo memory lpinfo) override public returns(bool isSuccess){
      Operations.TxInfo memory txinfo = getTxInfo(fromChainID,TxIndex);
      require(txinfo.from == msg.sender, 'owner user');
      // require(txinfo.to == makerAddress, 'makerAddress');
      require(extIndex <= lpinfo.avalibleTimes.length / 2, 'extIndex must be legitimate');

      uint256 punish = getTokenPunish(txinfo.amount);
      uint256 needBackTokenAmount = txinfo.amount * (1 + punish);

      uint256 needBackEthAmount = getETHGas(fromChainID,toChainID);
      // stack-eth
      // transfer eth & transfer token
    }

    function getETHGas(uint256 fromChainID, uint256 toChainID) override public returns(uint256 amount){
      return 100;
    }

    function maxWithdrawTime() override external view returns (uint) {
      return 100;
    }


    /// found chainid from amount
    function fromAmountGetChainId(uint256 amount)
        public
        returns (uint256 chainid)
    {

        chainid = 0;
    }

    function fromAmountCreatToAmount(
        uint256 fromAmount,
        uint256 nonce,
        uint256 gasfee,
        uint256 fee
    ) public returns (uint256 amount) {
        amount = 1;
    }
}
