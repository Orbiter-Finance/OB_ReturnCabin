// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operation.sol";

interface IORProtocal {
    function setChanllengePledgeAmountCoefficient(uint256 _wei) external;

    function getChanllengePledgeAmountCoefficient() external view returns (uint256);

    // function setDepositAmountCoefficient(uint16 hundredDigits) external;

    function setPauseAfterStopInterval(uint32 value) external;

    function getPauseAfterStopInterval() external view returns (uint256);

    // function getDepositAmountCoefficient() external view returns (uint16);

    function setTokenPunishCoefficient(uint16 hundredDigits) external;

    function getTokenPunishCoefficient() external view returns (uint16);

    function setETHPunishCoefficient(uint16 hundredDigits) external;

    function getETHPunishCoefficient() external view returns (uint16);

    function getPledgeAmount(uint256 batchLimit, uint256 maxPrice)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue);

    // function getTokenPunish(uint256 amount) external view returns (uint256 baseValue, uint256 additiveValue);

    // function getETHPunish(uint256 amount) external view returns (uint256 baseValue, uint256 additiveValue);
    function calculateCompensation(address token, uint256 value)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue);

    function getStartDealyTime(uint256 chainID) external view returns (uint256);

    function getStopDealyTime(uint256 chainID) external view returns (uint256);

    function getSecuirtyCode(bool isSource, uint256 amount) external view returns (uint256, bool);

    function getRespnseHash(OperationsLib.txInfo memory _txinfo) external pure returns (bytes32);

    function checkUserChallenge(OperationsLib.txInfo memory, bytes32[] memory) external view returns (bool);

    function checkMakerChallenge(
        OperationsLib.txInfo memory,
        OperationsLib.txInfo memory,
        bytes32[] memory
    ) external returns (bool);

    function maxWithdrawTime() external view returns (uint256);
}
