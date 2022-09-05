// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interface/IORProtocal.sol";
import "./interface/IORManager.sol";
import "./interface/IORSpv.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ORProtocalV1 is IORProtocal, Initializable, OwnableUpgradeable {
    address _managerAddress;

    function initialize(address managerAddress) public initializer {
        _managerAddress = managerAddress;
        __Ownable_init();
    }

    function getChanllengePledgeAmount() external pure returns (uint256) {
        return 0.05 * 10**18;
    }

    function getETHPunish(uint256 amount) external pure returns (uint256) {
        (uint256 securityCode, bool isSupport) = getSecuirtyCode(true, amount);
        require(isSupport, "GEP_AMOUNT_INVALIDATE");
        amount = amount - securityCode;
        return (amount * 11) / 100;
    }

    function getTokenPunish(uint256 amount) external pure returns (uint256) {
        (uint256 securityCode, bool isSupport) = getSecuirtyCode(true, amount);
        require(isSupport, "GTP_AMOUNT_INVALIDATE");
        amount = amount - securityCode;
        return (amount * 11) / 100;
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
        OperationsLib.lpInfo memory _lpinfo,
        uint256 stopTime,
        OperationsLib.txInfo memory _txinfo,
        bytes32[] memory _lpProof,
        bytes32[] memory _midProof,
        bytes32[] memory _txproof,
        bytes32 lpRootHash
    ) external view returns (bool) {
        require(_txinfo.sourceAddress == msg.sender, "UCE_SENDER");
        bytes32 lpid = OperationsLib.getLpID(_lpinfo);
        //1. txinfo is already spv
        address spvAddress = getSpvAddress();
        bool txVerify = IORSpv(spvAddress).verifyUserTxProof(_txinfo, _txproof);
        require(txVerify, "UCE_1");
        require(_lpinfo.sourceChain == _txinfo.chainID, "UCE_2");
        require(_lpinfo.sourceTAddress == _txinfo.tokenAddress, "UCE_3");
        require(_txinfo.destAddress == msg.sender, "UCE_4");
        require(_txinfo.sourceAddress == msg.sender, "UCE_5");
        require(_txinfo.timestamp > _lpinfo.startTime && _txinfo.timestamp < stopTime, "UCE_6");
        require(lpid == _txinfo.lpid, "UCE_7");
        //2. lpinfo is already proof
        bytes32 lp_leaf = OperationsLib.getLpFullHash(_lpinfo);
        // bool lpVerify = SpvLib.verify(lpRootHash, lp_leaf, _lpProof);
        bool lpVerify = false;

        require(lpVerify, "UCE_8");
        //3. stoptime & mid is already proof
        bytes32 mid_leaf = keccak256(abi.encodePacked(lp_leaf, keccak256(abi.encodePacked(stopTime))));
        // bool midVerify = SpvLib.verify(lpRootHash, mid_leaf, _midProof);
        bool midVerify = false;

        require(midVerify, "UCE_9");
        return true;
    }

    function checkMakerChallenge(
        OperationsLib.txInfo memory _makerTx,
        OperationsLib.txInfo memory _userTx,
        bytes32[] memory _makerProof
    ) external returns (bool) {
        address spvAddress = getSpvAddress();
        require(_makerTx.sourceAddress == msg.sender, "MC_SENDER");
        //1. _makerTx is already spv
        bool txVerify = IORSpv(spvAddress).verifyUserTxProof(_makerTx, _makerProof);
        require(txVerify, "MCE_UNVERIFY");

        OperationsLib.chainInfo memory souceChainInfo = IORManager(_managerAddress).getChainInfoByChainID(
            _userTx.chainID
        );
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
