// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IORProtocal.sol";
import "./interface/IORManager.sol";
import "./interface/IORSpv.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// import "hardhat/console.sol";

contract ORProtocalV1 is IORProtocal, Initializable, OwnableUpgradeable {
address controlContract;
uint256 public challengePledgedAmount;
uint32 public pledgeAmountSafeRate;
uint16 public mainCoinPunishRate;
uint16 public tokenPunishRate;

function initialize(
    address _controlContract,
    uint256 _challengePledgedAmount,
    uint32 _pledgeAmountSafeRate,
    uint16 _mainCoinPunishRate,
    uint16 _tokenPunishRate
) public initializer {
    require(_controlContract != address(0), "CONTROL_CONTRACT_ERROR: Control contract address is invalid");
    controlContract = _controlContract;
    challengePledgedAmount = _challengePledgedAmount;
    pledgeAmountSafeRate = _pledgeAmountSafeRate;
    mainCoinPunishRate = _mainCoinPunishRate;
    tokenPunishRate = _tokenPunishRate;
    __Ownable_init();
}

// The parameter here is the user challenge pledge factor in wei.
function setChallengePledgedAmount(uint256 value) external onlyOwner {
    challengePledgedAmount = value;
}

// The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
function setPledgeAmountSafeRate(uint32 value) external onlyOwner {
    pledgeAmountSafeRate = value;
}

function getPledgeAmountSafeRate() external view returns (uint32) {
    return pledgeAmountSafeRate;
}

// The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
function setMainCoinPunishRate(uint16 value) external onlyOwner {
    mainCoinPunishRate = value;
}

// The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
function setTokenPunishRate(uint16 value) external onlyOwner {
    tokenPunishRate = value;
}

function getPledgeAmount(uint256 batchLimit, uint256 maxPrice)
    external
    view
    returns (uint256 baseValue, uint256 additiveValue)
{
    require(batchLimit != 0 && maxPrice != 0 && pledgeAmountSafeRate != 0, "GET_PLEDGE_AMOUNT_ERROR: Invalid parameters");
    baseValue = (batchLimit * maxPrice);
    additiveValue = (baseValue * pledgeAmountSafeRate) / 100 / 100;
}

function calculateCompensation(address token, uint256 value)
    external
    view
    returns (uint256 baseValue, uint256 additiveValue)
{
require(value != 0 && tokenPunishRate != 0, "CALCULATE_COMPENSATION_ERROR: Invalid parameters");
baseValue = value;
additiveValue = (baseValue * tokenPunishRate) / 100;
}

function calculatePenalty(uint256 value) external view returns (uint256) {
require(value != 0 && mainCoinPunishRate != 0, "CALCULATE_PENALTY_ERROR: Invalid parameters");
return (value * mainCoinPunishRate) / 100;
}

function claimPenalty(address user) external {
IORManager manager = IORManager(controlContract);
require(manager.getPenaltyAmount(user) > 0, "CLAIM_PENALTY_ERROR: Penalty not found");
uint256 penalty = manager.getPenaltyAmount(user);
manager.transferPenalty(user, address(this));
require(msg.sender.send(penalty), "CLAIM_PENALTY_ERROR: Transfer failed");
}

function claimCompensation(address user, address token) external {
IORManager manager = IORManager(controlContract);
require(manager.getCompensationAmount(user, token) > 0, "CLAIM_COMPENSATION_ERROR: Compensation not found");
uint256 compensation = manager.getCompensationAmount(user, token);
manager.transferCompensation(user, token, address(this));
require(Token(token).transfer(msg.sender, compensation), "CLAIM_COMPENSATION_ERROR: Transfer failed");
}

function isSPV(address user) external view returns (bool) {
IORSpv spv = IORSpv(controlContract);
return spv.isSpv(user);
}

function isOracle(address user) external view returns (bool) {
IORManager manager = IORManager(controlContract);
return manager.isOracle(user);
}

function getBatchLimit(address oracle) external view returns (uint256) {
IORManager manager = IORManager(controlContract);
return manager.getBatchLimit(oracle);
}

function getMaxPrice(address oracle) external view returns (uint256) {
IORManager manager = IORManager(controlContract);
return manager.getMaxPrice(oracle);
}
}
