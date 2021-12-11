// SPDX-License-Identifier: BUSL-1.1 
pragma solidity =0.7.6;
pragma abicoder v2;
import './../Operations.sol';

interface IOrbiterMakerDeposit {

  function createLPInfo(
        uint256 fromChainID,
        uint256 toChainID,
        address fromTokenAddress,
        address toTokenAddress,
        address contractTokenAddress,
        uint256 avalibleETH,
        uint256 oneMax,
        uint256 oneMin,
        uint256 tradingFee,
        uint256 gasFee,
        address protocal,
        uint256 precision
    ) external;

    function LPType(Operations.LPInfo memory readyLPInfo) external returns(uint256);

    function LPAction(uint256 fromChainID,uint256 toChainID,address fromTokenAddress, address toTokenAddress, address contractTokenAddress) external returns(bool);

    function LPStop(uint256 fromChainID,uint256 toChainID,address fromTokenAddress, address toTokenAddress) external returns(bool);

    function releaseLPLiquidity(uint256 fromChainID,uint256 toChainID,address fromTokenAddress, address toTokenAddress) external;

    function makerWithdraw(
        address contractTokenAddress,
        uint256 withDrawETHAmount,
        uint256 withDrawTokenAmount
    ) external;

    function LPUpdate(
        uint256 fromChainID,
        uint256 toChainID,
        address fromTokenAddress,
        address toTokenAddress,
        uint256 _oneMax,
        uint256 _oneMin,
        uint256 _tradingFee,
        uint256 _gasFee,
        address _protocal
      ) external returns(bool);

    // user   (msg.sender == txinfo.from）
    function userChallengeAction(uint256 fromChainID,uint256 TxIndex,uint256 toChainID,address fromTokenAddress, address toTokenAddress,address contractTokenAddress,uint256 changeExtIndex) external returns(bool);

    // owner
    function makerChanllenge(uint256 fromChainID,uint256 fromTxIndex,uint256 toChainID,uint256 toTxIndex,address fromTokenAddress,address toTokenAddress,address contractTokenAddress,uint256 changeExtIndex) external returns(bool);

    function userChanllengeWithDraw(
            uint256 fromChainID,
            uint256 TxIndex,
            uint256 toChainID,
            address fromTokenAddress,
            address toTokenAddress,
            uint256 changeExtIndex,
            address contractTokenAddress
      ) external returns(bool);
}
