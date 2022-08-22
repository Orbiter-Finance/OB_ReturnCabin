// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORMakerDeposit {
    enum lpState {
        ACTION,
        UPDATE,
        PAUSE,
        STOP
    }
    event MakerContract(address indexed maker, address indexed mdc);
    event AddPariChain(address indexed tokenAddress, Operations.pairChainInfo pairChain);
    event AddPariChains(address indexed tokenAddress, Operations.pairChainInfo[] pairChains);
    event LogLpState(bytes32 indexed lpid, uint256 time, lpState indexed state);
    event LogLpInfo(
        bytes32 indexed lpid,
        uint256 indexed sourceChain,
        uint256 indexed destChain,
        Operations.lpInfo lpinfo
    );

    function LPAction(Operations.lpInfo memory) external payable;

    // LPPause
    function LPPause(Operations.lpInfo memory) external;

    // LPStop
    function LPStop(Operations.lpInfo memory) external;

    // LPUpdate
    function LPUpdate(
        Operations.lpInfo memory,
        bytes32 proof,
        bool[] memory
    ) external;

    // withDrawAssert()
    function withDrawAssert(uint256, address) external;

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
