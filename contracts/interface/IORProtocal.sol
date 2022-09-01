// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORProtocal {
    function getChanllengePledgeAmount() external returns (uint256);

    function getTokenPunish(uint256 amount) external returns (uint256);

    function getETHPunish(uint256 chainID) external returns (uint256);

    function getStartDealyTime(uint256 chainID) external returns (uint256);

    function getStopDealyTime(uint256 chainID) external returns (uint256);

    function getSecuirtyCode(bool isSource, uint256 amount) external returns (uint256, bool);

    function checkUserChallenge(
        OperationsLib.lpInfo memory,
        uint256,
        OperationsLib.txInfo memory,
        bytes32[] memory,
        bytes32[] memory,
        bytes32[] memory,
        bytes32
    ) external returns (bool);

    function checkMakerChallenge(
        OperationsLib.txInfo memory,
        OperationsLib.txInfo memory,
        bytes32[] memory
    ) external returns (bool);

    function userChanllengeWithDraw(OperationsLib.txInfo memory userInfo)
        external
        returns (
            bool,
            uint256,
            uint256
        );

    function maxWithdrawTime() external view returns (uint256);
}
