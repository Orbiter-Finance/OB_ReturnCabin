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

    function checkMakerChallenge(OperationsLib.Transaction memory _userTx, OperationsLib.Transaction memory _makerTx)
        external
        view
        returns (bool);

    function checkUserChallenge(uint256 value) external view returns (bool);


    function getPledgedAmount(uint256 chainId, uint256 maxPrice) external view returns (uint256 value);

    // function getManager() external view returns (address);

    function getPledgeAmount(uint256 batchLimit, uint256 maxPrice)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue);

    function getResponseAmount(OperationsLib.Transaction memory tx) external view returns (uint256);

    function getResponseHash(OperationsLib.Transaction memory tx, bool isSource) external view returns (bytes32);

    function getToTxNonceId(OperationsLib.Transaction memory tx) external view returns (uint256);

    function getValueSecuirtyCode(uint256 chainKey, uint256 value) external view returns (string memory);
}
