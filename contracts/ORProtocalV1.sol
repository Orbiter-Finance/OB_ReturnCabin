// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interface/IORProtocal.sol";
import "./library/Operation.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ORProtocalV1 is IORProtocal, Initializable, OwnableUpgradeable {
    function initialize() public initializer {
        __Ownable_init();
    }

    function getResponseTxHash() external pure returns (bytes32) {
        bytes32 responseInfoHash = "000000000";
        return responseInfoHash;
    }

    function getChanllengePledgeAmount() external pure returns (uint256) {
        return 0.05 * 10**18;
    }

    function isSupportChainID(uint256 chainID) external pure returns (bool) {
        return true;
    }

    function getDeposit(uint256 chainid, uint256 oneMax) external pure returns (uint256) {
        return 1;
    }

    function getTokenPunish(uint256 amount) external pure returns (uint256) {
        return 1;
    }

    function getETHPunish(uint256 fromChainID) external pure returns (uint256) {
        return 1;
    }

    function getDisputeTimeTime(uint256 chainID) external pure returns (uint256) {
        return 1;
    }

    function getStartDealyTime(uint256 chainID) external pure returns (uint256) {
        return 1;
    }

    function getStopDealyTime(uint256 chainID) external pure returns (uint256) {
        return 1;
    }

    function checkUserChallenge(
        OperationsLib.lpInfo memory,
        OperationsLib.txInfo memory,
        bytes memory proof
    ) external pure returns (bool) {
        return true;
    }

    function checkMakerChallenge(
        OperationsLib.txInfo memory,
        OperationsLib.txInfo memory,
        bytes memory proof
    ) external pure returns (bool) {
        return true;
    }

    function userChanllengeWithDraw(OperationsLib.txInfo memory userInfo)
        external
        pure
        returns (
            bool,
            uint256,
            uint256
        )
    {
        return (true, 1, 1);
    }

    function getETHGas(uint256 sourceChainID, uint256 destChainID) external pure returns (uint256) {
        return 1;
    }

    function maxWithdrawTime() external pure returns (uint256) {
        return 1;
    }
}
