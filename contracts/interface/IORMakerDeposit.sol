// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORMakerDeposit {
    enum lpState {
        ACTION,
        UPDATE,
        PAUSE,
        STOP,
        USERSTOP
    }
    enum chanllengeState {
        ACTION,
        RESPONSED,
        WITHDRAWED
    }

    event MakerContract(address indexed maker, address indexed mdc);
    event AddPariChain(address indexed tokenAddress, OperationsLib.pairChainInfo pairChain);
    event AddPariChains(address indexed tokenAddress, OperationsLib.pairChainInfo[] pairChains);
    event LogLpInfo(bytes32 indexed lpid, lpState indexed state, uint256 time, OperationsLib.lpInfo lpinfo);
    event LogLpInfo(bytes32 indexed lpid, lpState indexed state, uint256 time);

    event LogChanllengeInfo(bytes32 indexed chanllengeid, chanllengeState indexed state);

    function idleAmount(address tokenAddress) external view returns (uint256);

    function LPAction(
        OperationsLib.lpInfo[] calldata _lpinfos,
        bytes32[][] calldata proof,
        bytes32[][] calldata pairProof
    ) external payable;

    // LPPause
    function LPPause(OperationsLib.lpInfo[] calldata _lpinfos, bytes32[][] calldata proof) external;

    // LPStop
    function LPStop(OperationsLib.lpInfo memory) external;

    // LPUpdate
    function LPUpdate(OperationsLib.lpInfo calldata _lpinfo) external;

    // withDrawAssert()
    function withDrawAssert(uint256, address) external;

    // userChanllenge
    function userChanllenge(OperationsLib.txInfo memory, bytes32[] memory) external payable;

    // userWithDraw
    function userWithDraw(OperationsLib.txInfo memory, OperationsLib.lpInfo memory) external;

    // makerChanllenger
    function makerChanllenger(
        OperationsLib.txInfo memory,
        OperationsLib.txInfo memory,
        bytes32[] memory
    ) external;
}
