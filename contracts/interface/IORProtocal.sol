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
        OperationsLib.Transaction memory _userTx,
        OperationsLib.Transaction memory _makerTx,
        bytes32[] memory _makerProof
    ) external view returns (bool);

    function checkUserChallenge(OperationsLib.Transaction memory _tx, bytes32[] memory _txproof)
        external
        view
        returns (bool);

    function getFromTxChainId(OperationsLib.Transaction memory tx) external view returns (uint256);
    function getPledgedAmount(uint256 chainId, uint256 maxPrice)
        external
        view
        returns (uint256 value);
    // function getManager() external view returns (address);

    function getPledgeAmount(uint256 batchLimit, uint256 maxPrice)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue);

    function getResponseAmount(OperationsLib.Transaction memory tx) external pure returns (uint256);

    function getResponseHash(OperationsLib.Transaction memory tx, bool isSource) external view returns (bytes32);

    function getToTxNonceId(OperationsLib.Transaction memory tx) external view returns (uint256);

    function getValueSecuirtyCode(uint256 chainKey, uint256 value) external view returns (string memory);

    function initialize(
        address _manager,
        uint256 _challengePledgedAmount,
        uint256 _pledgeAmountSafeRate,
        uint256 _mainCoinPunishRate,
        uint256 _tokenPunishRate
    ) external;

    function mainCoinPunishRate() external view returns (uint256);

    function pledgeAmountSafeRate() external view returns (uint256);

    function setChallengePledgedAmount(uint256 value) external;

    function setMainCoinPunishRate(uint256 value) external;

    function setPledgeAmountSafeRate(uint256 value) external;

    function setTokenPunishRate(uint256 value) external;

    function tokenPunishRate() external view returns (uint256);
}
