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
        require(_controlContract != address(0), "Owner address error");
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
        require(batchLimit != 0 && maxPrice != 0 && pledgeAmountSafeRate != 0, "GET_DEPOSITCOEFFICIENT_ERROR");
        baseValue = (batchLimit * maxPrice);
        additiveValue = (baseValue * pledgeAmountSafeRate) / 100 / 100;
    }

    function calculateCompensation(address token, uint256 value)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue)
    {
        baseValue = value;
        if (token == address(0)) {
            additiveValue = (baseValue * mainCoinPunishRate) / 100 / 100;
        } else {
            additiveValue = (baseValue * tokenPunishRate) / 100 / 100;
        }
    }

    function getSecuirtyCode(bool isSource, uint256 amount) public pure returns (uint256, bool) {
        uint256 securityCode = 0;
        bool isSupport = true;
        if (isSource) {
            securityCode = (amount % 10000) - 9000;
        } else {
            securityCode = amount % 10000;
        }
        return (securityCode, isSupport);
    }

    function getRespnseHash(OperationsLib.txInfo memory _txinfo) external pure returns (bytes32) {
        (uint256 securityCode, bool sourceIsSupport) = getSecuirtyCode(true, _txinfo.amount);
        (uint256 nonce, bool responseIsSupport) = getSecuirtyCode(false, _txinfo.responseAmount);

        require(sourceIsSupport && responseIsSupport, "GRH_ERROR");

        require(_txinfo.nonce < 9000, "GRH_NONCE_ERROR1");

        // require(nonce == _txinfo.nonce, "GRH_NONCE_ERROR2");

        bytes32 needRespnse = keccak256(
            abi.encodePacked(
                _txinfo.lpid,
                securityCode,
                _txinfo.destAddress,
                _txinfo.sourceAddress,
                _txinfo.responseAmount,
                _txinfo.responseSafetyCode,
                _txinfo.tokenAddress
            )
        );
        return needRespnse;
    }

    function checkUserChallenge(OperationsLib.txInfo memory _txinfo, bytes32[] memory _txproof)
        external
        view
        returns (bool)
    {
        // bytes32 lpid = _txinfo.lpid;
        //1. txinfo is already spv
        address spvAddress = getSpvAddress();
        // Verify that txinfo and txproof are valid
        bool txVerify = IORSpv(spvAddress).verifyUserTxProof(_txinfo, _txproof);
        require(txVerify, "UCE_1");

        return true;
    }

    function checkMakerChallenge(
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
        bytes32[] memory _makerProof
    ) external view returns (bool) {
        address spvAddress = getSpvAddress();

        //1. _makerTx is already spv
        bool txVerify = IORSpv(spvAddress).verifyMakerTxProof(_makerTx, _makerProof);
        require(txVerify, "MCE_UNVERIFY");

        OperationsLib.chainInfo memory souceChainInfo = IORManager(controlContract).getChainInfoByChainID(
            _userTx.chainID
        );
        // The transaction time of maker is required to be later than that of user.
        // At the same time, the time difference between the above two times is required to be less than the maxDisputeTime.
        require(
            _makerTx.timestamp - _userTx.timestamp > 0 &&
                _makerTx.timestamp - _userTx.timestamp < souceChainInfo.maxDisputeTime,
            "MCE_TIMEINVALIDATE"
        );
        return true;
    }

    function maxWithdrawTime() external pure returns (uint256) {
        return 1;
    }

    function getSpvAddress() internal view returns (address) {
        address spvAddress = IORManager(controlContract).spv();
        require(spvAddress != address(0), "SPV_NOT_INSTALL");
        return spvAddress;
    }
}
