// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORProtocal {
    function setChanllengePledgeAmountCoefficient(uint256 _wei) external;

    function getChanllengePledgeAmountCoefficient() external view returns (uint256);

    function setDepositAmountCoefficient(uint256 hundredDigits) external;

    function getDepositAmountCoefficient() external view returns (uint256);

    function setTokenPunishCoefficient(uint256 hundredDigits) external;

    function getTokenPunishCoefficient() external view returns (uint256);

    function setETHPunishCoefficient(uint256 hundredDigits) external;

    function getETHPunishCoefficient() external view returns (uint256);

    function getDepositAmount(uint256 batchLimit, uint256 maxPrice) external view returns (uint256);

    function getTokenPunish(uint256 amount) external view returns (uint256);

    function getETHPunish(uint256 amount) external view returns (uint256);

    function getStartDealyTime(uint256 chainID) external view returns (uint256);

    function getStopDealyTime(uint256 chainID) external view returns (uint256);

    function getSecuirtyCode(bool isSource, uint256 amount) external view returns (uint256, bool);

    function getRespnseHash(OperationsLib.txInfo memory _txinfo) external pure returns (bytes32);

    function checkUserChallenge(
        OperationsLib.txInfo memory,
        bytes32[] memory,
        address from
    ) external view returns (bool);

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
