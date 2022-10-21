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

    event LogLPStop(bytes32 indexed pairId, bytes32 lpId);
    event ChainDepositChange(address indexed makerId, address token, uint256 amount, uint256 useLimit, bytes32[] pairs);
    event LogLpInfo(bytes32 indexed pairId, bytes32 lpId, lpState indexed state, OperationsLib.lpInfo lpinfo);
    event LogChanllengeInfo(
        uint256 indexed chainId,
        chanllengeState indexed opType,
        bytes32 chanllengeId,
        OperationsLib.txInfo txInfo,
        OperationsLib.chanllengeInfo chanllenge
    );

    function idleAmount(address tokenAddress) external view returns (uint256);

    function LPAction(OperationsLib.lpInfo[] calldata _lpinfos, bytes32[][] calldata pairProof) external payable;

    // LPPause
    function LPPause(OperationsLib.lpInfo[] calldata _lpinfos) external;

    // LPStop
    function LPStop(OperationsLib.lpInfo[] calldata _lpinfos) external;

    // LPUpdate
    function LPUpdate(OperationsLib.lpInfo[] calldata _lpinfos) external;

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
