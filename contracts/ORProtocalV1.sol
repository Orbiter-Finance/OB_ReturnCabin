// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IORProtocal.sol";
import "./interface/IORManager.sol";
import "./interface/IORSpv.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ORProtocalV1 is IORProtocal, Initializable, OwnableUpgradeable {
    IORManager public getManager;
    uint256 public challengePledgedAmount;
    uint256 public pledgeAmountSafeRate;
    uint256 public mainCoinPunishRate;
    uint256 public tokenPunishRate;

    function initialize(
        address _manager,
        uint256 _challengePledgedAmount,
        uint256 _pledgeAmountSafeRate,
        uint256 _mainCoinPunishRate,
        uint256 _tokenPunishRate
    ) external initializer {
        require(_manager != address(0), "Owner address error");
        getManager = IORManager(_manager);
        challengePledgedAmount = _challengePledgedAmount;
        pledgeAmountSafeRate = _pledgeAmountSafeRate;
        mainCoinPunishRate = _mainCoinPunishRate;
        tokenPunishRate = _tokenPunishRate;
        __Ownable_init();
    }

    // The parameter here is the user challenge pledge factor in wei.
    function setChallengePledgedAmount(uint256 value) external onlyOwner {
        challengePledgedAmount = value;
        emit ChangeChallengePledgedAmount(value);
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setPledgeAmountSafeRate(uint256 value) external onlyOwner {
        pledgeAmountSafeRate = value;
        emit ChangePledgeAmountSafeRate(value);
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setMainCoinPunishRate(uint256 value) external onlyOwner {
        mainCoinPunishRate = value;
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setTokenPunishRate(uint256 value) external onlyOwner {
        tokenPunishRate = value;
    }

    function getPledgeAmount(uint256 batchLimit, uint256 maxPrice)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue)
    {
        require(batchLimit != 0 && maxPrice != 0 && pledgeAmountSafeRate != 0, "GET_DEPOSITCOEFFICIENT_ERROR");
        baseValue = (batchLimit * maxPrice);
        additiveValue = (baseValue * pledgeAmountSafeRate) / 10000;
    }

    function calculateCompensation(address token, uint256 value)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue)
    {
        baseValue = value;
        if (token == address(0)) {
            additiveValue = (baseValue * mainCoinPunishRate) / 10000;
        } else {
            additiveValue = (baseValue * tokenPunishRate) / 10000;
        }
    }

    function getSourceTxSecuirtyCode(uint256 value) public pure returns (uint256) {
        uint256 code = (value % 10000) - 9000;
        return code;
    }

    function getTargetTxSecuirtyCode(uint256 value) public pure returns (uint256) {
        uint256 code = (value % 10000);
        return code;
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
        (, bool responseIsSupport) = getSecuirtyCode(false, _txinfo.responseAmount);

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
        address spvAddress = getManager.getSPV();
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
        address spvAddress = getManager.getSPV();

        //1. _makerTx is already spv
        bool txVerify = IORSpv(spvAddress).verifyMakerTxProof(_makerTx, _makerProof);
        require(txVerify, "MCE_UNVERIFY");
        (, , uint256 maxDisputeTime, , , ) = getManager.getChain(_userTx.chainID);
        // The transaction time of maker is required to be later than that of user.
        // At the same time, the time difference between the above two times is required to be less than the maxDisputeTime.
        require(
            _makerTx.timestamp - _userTx.timestamp > 0 && _makerTx.timestamp - _userTx.timestamp < maxDisputeTime,
            "MCE_TIMEINVALIDATE"
        );
        return true;
    }
}
