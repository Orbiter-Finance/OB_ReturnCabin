// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interface/IORProtocal.sol";
import "./interface/IORManager.sol";
import "./interface/IORSpv.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

contract ORProtocalV1 is IORProtocal, Initializable, OwnableUpgradeable {
    address _managerAddress;
    uint256 public ChanllengePledgeAmountCoefficient;
    uint256 public DepositAmountCoefficient;
    uint256 public EthPunishCoefficient;
    uint256 public TokenPunishCoefficient;

    function initialize(address managerAddress) public initializer {
        _managerAddress = managerAddress;
        __Ownable_init();
    }

    // The parameter here is the user challenge pledge factor in wei.
    function setChanllengePledgeAmountCoefficient(uint256 _wei) external onlyOwner returns (bool) {
        ChanllengePledgeAmountCoefficient = _wei;
        return true;
    }

    function getChanllengePledgeAmountCoefficient() external view returns (uint256) {
        return ChanllengePledgeAmountCoefficient;
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setDepositAmountCoefficient(uint256 hundredDigits) external onlyOwner returns (bool) {
        DepositAmountCoefficient = hundredDigits;
        return true;
    }

    function getDepositAmountCoefficient() external view returns (uint256) {
        return DepositAmountCoefficient;
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setETHPunishCoefficient(uint256 hundredDigits) external onlyOwner returns (bool) {
        EthPunishCoefficient = hundredDigits;
        return true;
    }

    function getETHPunishCoefficient() external view returns (uint256) {
        return EthPunishCoefficient;
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setTokenPunishCoefficient(uint256 hundredDigits) external onlyOwner returns (bool) {
        TokenPunishCoefficient = hundredDigits;
        return true;
    }

    function getTokenPunishCoefficient() external view returns (uint256) {
        return TokenPunishCoefficient;
    }

    function getDepositAmount(uint256 batchLimit, uint256 maxPrice) external view returns (uint256) {
        require(batchLimit != 0 && maxPrice != 0 && DepositAmountCoefficient != 0, "GET_DEPOSITCOEFFICIENT_ERROR");
        return (batchLimit * maxPrice * DepositAmountCoefficient) / 100;
    }

    function getETHPunish(uint256 amount) external view returns (uint256) {
        (uint256 securityCode, bool isSupport) = getSecuirtyCode(true, amount);
        require(isSupport, "GEP_AMOUNT_INVALIDATE");
        amount = amount - securityCode;
        return (amount * EthPunishCoefficient) / 100;
    }

    function getTokenPunish(uint256 amount) external view returns (uint256) {
        (uint256 securityCode, bool isSupport) = getSecuirtyCode(true, amount);
        require(isSupport, "GTP_AMOUNT_INVALIDATE");
        amount = amount - securityCode;
        return (amount * TokenPunishCoefficient) / 100;
    }

    function getStartDealyTime(uint256 chainID) external pure returns (uint256) {
        require(chainID != 0, "CHAINID_ERROR");
        return 1000;
    }

    function getStopDealyTime(uint256 chainID) external pure returns (uint256) {
        require(chainID != 0, "CHAINID_ERROR");
        return 1000;
    }

    function getSecuirtyCode(bool isSource, uint256 amount) public pure returns (uint256, bool) {
        uint256 securityCode = 0;
        bool isSupport = true;
        if (isSource) {
            // TODO  securityCode is support?
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

        require(nonce == _txinfo.nonce, "GRH_NONCE_ERROR2");

        bytes32 needRespnse = keccak256(
            abi.encodePacked(
                _txinfo.lpid,
                securityCode,
                _txinfo.destAddress,
                _txinfo.sourceAddress,
                _txinfo.responseAmount,
                _txinfo.tokenAddress
            )
        );
        return needRespnse;
    }

    function checkUserChallenge(
        OperationsLib.txInfo memory _txinfo,
        bytes32[] memory _txproof,
        address from
    ) external view returns (bool) {
        // Determine whether sourceAddress in txinfo is consistent with the caller's address
        require(_txinfo.sourceAddress == from, "UCE_SENDER");
        bytes32 lpid = _txinfo.lpid;
        //1. txinfo is already spv
        address spvAddress = getSpvAddress();
        // Verify that txinfo and txproof are valid
        bool txVerify = IORSpv(spvAddress).verifyUserTxProof(_txinfo, _txproof);
        require(txVerify, "UCE_1");
        // Determine whether destAddress in txinfo is an MDC address
        require(_txinfo.destAddress == msg.sender, "UCE_4");
        return true;
    }

    function checkMakerChallenge(
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
        bytes32[] memory _makerProof
    ) external view returns (bool) {
        address spvAddress = getSpvAddress();
        // Determine whether sourceAddress in txinfo is an MDC address
        require(_makerTx.sourceAddress == msg.sender, "MC_SENDER");
        //1. _makerTx is already spv
        bool txVerify = IORSpv(spvAddress).verifyMakerTxProof(_makerTx, _makerProof);
        require(txVerify, "MCE_UNVERIFY");

        OperationsLib.chainInfo memory souceChainInfo = IORManager(_managerAddress).getChainInfoByChainID(
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

    function maxWithdrawTime() external pure returns (uint256) {
        return 1;
    }

    function getSpvAddress() internal view returns (address) {
        address spvAddress = IORManager(_managerAddress).getSPV();
        require(spvAddress != address(0), "SPV_NOT_INSTALL");
        return spvAddress;
    }
}
