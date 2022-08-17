// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORProtocal {
    function isSupportChainID(uint256 chainID) external returns (bool);

    function getDeposit(uint256 chainid, uint256 oneMax) external returns (uint256);

    function getTokenPunish(uint256 amount) external view returns (uint256);

    function getETHPunish(uint256 fromChainID) external view returns (uint256);

    function getDisputeTimeTime(uint256 chainID) external returns (uint256);

    function getStartDealyTime(uint256 chainID) external view returns (uint256);

    function getStopDealyTime(uint256 chainID) external view returns (uint256);

    function checkUserChallenge(
        Operations.lpInfo memory,
        Operations.txInfo memory,
        bytes memory proof
    ) external returns (bool);

    function checkMakerChallenge(
        Operations.txInfo memory,
        Operations.txInfo memory,
        bytes memory proof
    ) external returns (bool);

    function userChanllengeWithDraw(Operations.txInfo memory userInfo)
        external
        returns (
            bool,
            uint256,
            uint256
        );

    function getETHGas(uint256 sourceChainID, uint256 destChainID) external returns (uint256);

    function maxWithdrawTime() external view returns (uint256);
}