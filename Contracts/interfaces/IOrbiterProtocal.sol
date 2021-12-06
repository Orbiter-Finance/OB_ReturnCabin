// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import './../Operations.sol';

interface IOrbiterProtocal {
    function isSupportChainID(uint256 chainID) external returns (bool);

    function getDeposit(uint256 chainid, uint256 oneMax) external returns (uint256);

    function getTokenPunish(uint256 amount) external view returns (uint256);

    function getETHPunish(uint256 fromChainID) external view returns (uint256);

    function getTxInfo(uint256 chainID,uint256 txIndex) external returns (Operations.TxInfo memory);

    function getDisputeTimeTime(uint256 chainID) external returns (uint256);

    function getStartDealyTime(uint256 chainID) external view returns (uint256);

    function getStopDealyTime(uint256 chainID) external view returns (uint256);

    function checkUserChallenge(uint256 fromChainID,uint256 TxIndex,uint256 extIndex,uint256 toChainID, Operations.LPInfo memory lpinfo, Operations.PoolExt memory ext) external returns(bool);

    function checkMakerChallenge(uint256 fromChainID,uint256 fromTxIndex,uint256 extIndex,uint256 toChainID,uint256 toTxIndex,Operations.LPInfo memory lpinfo) external returns(bool);

    function userChanllengeWithDraw(uint256 fromChainID,uint256 TxIndex,uint256 extIndex,uint256 toChainID, Operations.LPInfo memory lpinfo) external returns(bool);

    function getETHGas(uint256 fromChainID, uint256 toChainID) external returns(uint256);

    function maxWithdrawTime() external view returns (uint);
}
