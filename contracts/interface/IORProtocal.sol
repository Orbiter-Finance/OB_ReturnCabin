// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operation.sol";

interface IORProtocal {
    event ChangeChallengePledgedAmount(uint256 value);
    event ChangePledgeAmountSafeRate(uint256 value);

    function calculateCompensation(address token, uint256 value)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue);

    function challengePledgedAmount() external view returns (uint256);

    function checkMakerChallenge(
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
        bytes32[] memory _makerProof
    ) external view returns (bool);

    function checkUserChallenge(OperationsLib.txInfo memory _txinfo, bytes32[] memory _txproof)
        external
        view
        returns (bool);

    function getPledgeAmount(uint256 batchLimit, uint256 maxPrice)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue);

    function getPledgeAmountSafeRate() external view returns (uint32);

    function getRespnseHash(OperationsLib.txInfo memory _txinfo) external pure returns (bytes32);

    function getSecuirtyCode(bool isSource, uint256 amount) external pure returns (uint256, bool);

    function initialize(
        address _controlContract,
        uint256 _challengePledgedAmount,
        uint32 _pledgeAmountSafeRate,
        uint16 _mainCoinPunishRate,
        uint16 _tokenPunishRate
    ) external;

    function mainCoinPunishRate() external view returns (uint16);

    function pledgeAmountSafeRate() external view returns (uint32);

    function setChallengePledgedAmount(uint256 _wei) external;

    function setMainCoinPunishRate(uint16 value) external;

    function setPledgeAmountSafeRate(uint32 value) external;

    function setTokenPunishRate(uint16 value) external;

    function tokenPunishRate() external view returns (uint16);
}
