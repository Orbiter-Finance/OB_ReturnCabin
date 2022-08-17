// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORMakerDeposit {
    enum lpState {
        CREAT,
        ACTION,
        PAUSE,
        STOP
    }
    event AddPariChain(address indexed tokenAddress, Operations.pairChainInfo pairChain);
    event AddPariChains(address indexed tokenAddress, Operations.pairChainInfo[] pairChains);
    event LogLpState(bytes32 indexed lpid, uint256 time, lpState indexed state);
    event LogLpInfo(
        bytes32 indexed lpid,
        uint256 indexed sourceChain,
        uint256 indexed destChain,
        Operations.lpInfo lpinfo
    );

    function LPCreate(Operations.lpInfo memory) external returns (bool);

    // LPAction
    function LPAction(bytes32) external returns (bool);

    // LPPause
    function LPPause(bytes32) external returns (bool);

    // LPStop
    function LPStop(bytes32) external returns (bool);

    // LPUpdate
    function LPUpdate(
        bytes32 lpid,
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
