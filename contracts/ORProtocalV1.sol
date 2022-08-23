// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interface/IORProtocal.sol";
import "./library/Operation.sol";
import "hardhat/console.sol";

contract ORProtocalV1 is IORProtocal {
    address _owner;

    constructor(address owner) payable {
        _owner = owner;
    }

    function isSupportChainID(uint256 chainID) external returns (bool) {
        return true;
    }

    function getDeposit(uint256 chainid, uint256 oneMax) external returns (uint256) {
        return 1;
    }

    function getTokenPunish(uint256 amount) external view returns (uint256) {
        return 1;
    }

    function getETHPunish(uint256 fromChainID) external view returns (uint256) {
        return 1;
    }

    function getDisputeTimeTime(uint256 chainID) external returns (uint256) {
        return 1;
    }

    function getStartDealyTime(uint256 chainID) external view returns (uint256) {
        return 1;
    }

    function getStopDealyTime(uint256 chainID) external view returns (uint256) {
        return 1;
    }

    function checkUserChallenge(
        Operations.lpInfo memory,
        Operations.txInfo memory,
        bytes memory proof
    ) external returns (bool) {
        return true;
    }

    function checkMakerChallenge(
        Operations.txInfo memory,
        Operations.txInfo memory,
        bytes memory proof
    ) external returns (bool) {
        return true;
    }

    function userChanllengeWithDraw(Operations.txInfo memory userInfo)
        external
        returns (
            bool,
            uint256,
            uint256
        )
    {
        return (true, 1, 1);
    }

    function getETHGas(uint256 sourceChainID, uint256 destChainID) external returns (uint256) {
        return 1;
    }

    function maxWithdrawTime() external view returns (uint256) {
        return 1;
    }
}
