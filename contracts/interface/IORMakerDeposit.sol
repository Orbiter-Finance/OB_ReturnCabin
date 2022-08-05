// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORMakerDeposit {
    event AddPariChain(address indexed tokenAddress, Operations.pairChainInfo pairChain);
    event AddPariChains(address indexed tokenAddress, Operations.pairChainInfo[] pairChains);

    function LPCreate(Operations.lpInfo memory) external returns (bool);

    // LPAction
    function LPAction(uint256 lpid) external returns (bool);

    // LPPause
    function LPPause(uint256 lpid) external returns (bool);

    // LPStop
    function LPStop(uint256 lpid) external returns (bool);

    // LPUpdate
    function LPUpdate(
        uint256 lpid,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 gasFee,
        uint256 tradingFee
    ) external returns (bool);

    // withDrawAssert()
    function withDrawAssert(uint256 amount, bytes memory token) external returns (bool);

    // userChanllenge
    function userChanllenge(
        Operations.lpInfo memory,
        Operations.txInfo memory,
        bytes memory proof
    ) external returns (bool);

    // userWithDraw
    function userWithDraw(Operations.txInfo memory) external returns (bool);

    // makerChanllenger
    function makerChanllenger(
        Operations.txInfo memory,
        Operations.txInfo memory,
        bytes memory
    ) external returns (bool);
}
