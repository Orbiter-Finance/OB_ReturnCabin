// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IORProtocal.sol";
import "./interface/IORManager.sol";
import "./interface/IORSpv.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

contract ORProtocalV1 is IORProtocal, Initializable, OwnableUpgradeable {
    address controlContract;
    uint256 public ChanllengePledgeAmountCoefficient;
    // * 100
    uint32 public pledgeAmountSafeRate;
    // uint16 public DepositAmountCoefficient;
    uint16 public EthPunishCoefficient;
    uint16 public TokenPunishCoefficient;
    uint32 public PauseAfterStopInterval;

    function initialize(
        address _controlContract,
        uint256 _chanllengePledgeAmountCoefficient,
        uint32 _pledgeAmountSafeRate,
        uint16 _ethPunishCoefficient,
        uint16 _tokenPunishCoefficie,
        uint32 _pauseAfterStopInterval
    ) public initializer {
        require(_controlContract != address(0), "Owner address error");
        controlContract = _controlContract;
        ChanllengePledgeAmountCoefficient = _chanllengePledgeAmountCoefficient;
        pledgeAmountSafeRate = _pledgeAmountSafeRate;
        EthPunishCoefficient = _ethPunishCoefficient;
        TokenPunishCoefficient = _tokenPunishCoefficie;
        PauseAfterStopInterval = _pauseAfterStopInterval;
        __Ownable_init();
    }

    function setPauseAfterStopInterval(uint32 value) external onlyOwner {
        PauseAfterStopInterval = value;
    }

    function getPauseAfterStopInterval() external view returns (uint256) {
        return PauseAfterStopInterval;
    }

    // The parameter here is the user challenge pledge factor in wei.
    function setChanllengePledgeAmountCoefficient(uint256 _wei) external onlyOwner {
        ChanllengePledgeAmountCoefficient = _wei;
    }

    function getChanllengePledgeAmountCoefficient() external view returns (uint256) {
        return ChanllengePledgeAmountCoefficient;
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setPledgeAmountSafeRate(uint32 value) external onlyOwner {
        pledgeAmountSafeRate = value;
    }

    function getPledgeAmountSafeRate() external view returns (uint32) {
        return pledgeAmountSafeRate;
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setETHPunishCoefficient(uint16 hundredDigits) external onlyOwner {
        EthPunishCoefficient = hundredDigits;
    }

    function getETHPunishCoefficient() external view returns (uint16) {
        return EthPunishCoefficient;
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setTokenPunishCoefficient(uint16 hundredDigits) external onlyOwner {
        TokenPunishCoefficient = hundredDigits;
    }

    function getTokenPunishCoefficient() external view returns (uint16) {
        return TokenPunishCoefficient;
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
            additiveValue = (baseValue * EthPunishCoefficient) / 100 / 100;
        } else {
            additiveValue = (baseValue * TokenPunishCoefficient) / 100 / 100;
        }
    }

    function getStartDealyTime(uint256 chainID) external pure returns (uint256) {
        require(chainID != 0, "CHAINID_ERROR");
        return 500;
    }

    function getStopDealyTime(uint256 chainID) external view returns (uint256) {
        require(chainID != 0, "CHAINID_ERROR");
        return PauseAfterStopInterval;
        // return 60 * 60 * 1;
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
        address spvAddress = IORManager(controlContract).getSPV();
        require(spvAddress != address(0), "SPV_NOT_INSTALL");
        return spvAddress;
    }
}
