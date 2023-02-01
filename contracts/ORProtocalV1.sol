// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IORProtocal.sol";
import "./interface/IORManager.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {StrSlice, toSlice, StrChar, StrChar__} from "./stringutils/StrSlice.sol";

contract ORProtocalV1 is IORProtocal, Initializable, OwnableUpgradeable {
    IORManager public getManager;
    OperationsLib.EBCConfigStruct public config;
    using {toSlice} for string;

    // mapping(uint16 => uint256) idChainID;

    function initialize(
        address _manager,
        OperationsLib.EBCConfigStruct calldata _config
    ) external initializer {
        require(_manager != address(0), "Owner address error");
        getManager = IORManager(_manager);
        config = _config;
        __Ownable_init();
    }

    // The parameter here is the user challenge pledge factor in wei.
    function setChallengePledgedAmount(uint256 value) external onlyOwner {
        config.challengePledgedAmount = value;
        emit ChangeChallengePledgedAmount(value);
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setPledgeAmountSafeRate(uint16 value) external onlyOwner {
        config.pledgeAmountSafeRate = value;
        emit ChangePledgeAmountSafeRate(value);
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setMainCoinPunishRate(uint16 value) external onlyOwner {
        config.mainCoinPunishRate = value;
    }

    // The parameter is a number of percentile precision, for example: When tenDigits is 110, it represents 1.1
    function setTokenPunishRate(uint16 value) external onlyOwner {
        config.tokenPunishRate = value;
    }
    function getPledgedAmount(uint256 chainId, uint256 maxPrice)
        external
        view
        returns (uint256 value)
    {
        require(chainId != 0, "chain not exist");
        (, , uint256 batchLimit, , , ,) = getManager.getChain(chainId);
        require(batchLimit != 0 && maxPrice != 0 && config.pledgeAmountSafeRate != 0, "PledgeAmountSafeRate Non Set");
        return ((batchLimit * maxPrice) * config.pledgeAmountSafeRate) / 10000;
    }
    function getPledgeAmount(uint256 batchLimit, uint256 maxPrice)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue)
    {
        require(batchLimit != 0 && maxPrice != 0 && config.pledgeAmountSafeRate != 0, "PledgeAmountSafeRate Non Set");
        baseValue = (batchLimit * maxPrice);
        additiveValue = (baseValue * config.pledgeAmountSafeRate) / 10000;
    }

    function calculateCompensation(address token, uint256 value)
        external
        view
        returns (uint256 baseValue, uint256 additiveValue)
    {
        baseValue = value;
        if (token == address(0)) {
            additiveValue = (baseValue * config.mainCoinPunishRate) / 10000;
        } else {
            additiveValue = (baseValue * config.tokenPunishRate) / 10000;
        }
    }

    function getAmountValidDigits(
        string memory value,
        uint256 maxUint
    ) internal pure returns (uint256) {
        StrSlice strValue = value.toSlice();
        uint256 maxValue = maxUint < 256 ? 2**maxUint - 1 : type(uint256).max;
        StrSlice maxValueSlice = Strings.toString(maxValue).toSlice();
        // // uint i = strValue.len() - 1;
        // // StrSlice removeSidesZero;
        uint256 valueLen = strValue.len();
        uint256 subnum = 0;
        for (uint256 i = 0; i < valueLen; i++) {
            // if (removeSidesZero.isEmpty()) {
            //     if (strValue.get(valueMaxLen - i - 1).toCodePoint() != 48) {
            //         removeSidesZero = strValue.getSubslice(0, valueMaxLen - i);
            //     }
            // }
            uint256 num1 = strValue.get(i).toCodePoint();
            uint256 num2 = maxValueSlice.get(i).toCodePoint();
            if (num1 != num2) {
                subnum = num1 > num2 ? 1 : 0;
                break;
            }
        }
        return maxValueSlice.len() - subnum;
    }

    function getValueSecuirtyCode(uint256 chainKey, uint256 value) public view returns (string memory) {
        (, , , , , , uint256 maxUint) = getManager.getChain(chainKey);
        require(maxUint != 0, "Maximum bits not set");
        require(maxUint <= 256, "The maximum bits exceeds 256");
        StrSlice strValue = Strings.toString(value).toSlice();
        uint256 valueMaxLen = strValue.len();
        require(valueMaxLen >= 4, "validDigit Error");
        uint256 validDigit = getAmountValidDigits(strValue.toString(), maxUint);
        require(validDigit > 0, "validDigit Error");
        if (maxUint < 256 && valueMaxLen > validDigit) {
            strValue = strValue.getSubslice(0, validDigit);
        }
        strValue = strValue.getSubslice(strValue.len() - 4, strValue.len());
        return strValue.toString();
    }

    function getFromTxChainId(OperationsLib.Transaction calldata tx) public view returns (uint256) {
        uint256 chainKey = getManager.idChainID(tx.chainId);
        (uint256 chainId, , , , , , ) = getManager.getChain(chainKey);
        require(chainId != 0, "chainId not set");
        string memory toChainId = getValueSecuirtyCode(chainId, tx.value);
        uint256 code = OperationsLib.stringToUint(toChainId);
        return code;
    }

    function getToTxNonceId(OperationsLib.Transaction calldata tx) public view returns (uint256) {
        uint256 chainKey = getManager.idChainID(tx.chainId);
        (uint256 chainId, , , , , , ) = getManager.getChain(chainKey);
        require(chainId != 0, "chainId not set");
        string memory toChainId = getValueSecuirtyCode(chainId, tx.value);
        uint256 code = OperationsLib.stringToUint(toChainId);
        return code;
    }

    function getResponseAmount(OperationsLib.Transaction calldata tx) external pure returns (uint256) {
        // get pairId & lpInfo
        return 9990000000000071;
    }

    function getResponseHash(OperationsLib.Transaction calldata tx, bool isSource) external view returns (bytes32) {
        if (isSource) {
            uint256 toChainId = this.getFromTxChainId(tx);
            require(toChainId != 0, "chainId not set");
            uint256 responseAmount = this.getResponseAmount(tx);
            return keccak256(abi.encodePacked(tx.from, tx.to, toChainId, tx.nonce, responseAmount));
        } else {
            uint256 chainKey = getManager.idChainID(tx.chainId);
            require(chainKey != 0, "chainKey not set");
            uint256 fromNonce = this.getToTxNonceId(tx);
            return keccak256(abi.encodePacked(tx.to, tx.from, chainKey, fromNonce, tx.value));
        }
    }

    function checkUserChallenge(OperationsLib.Transaction memory _tx, uint256 value)
        external
        view
        returns (
            bool
        )
    {
        require(value >= config.challengePledgedAmount);
        return true;
    }

    function checkMakerChallenge(
        OperationsLib.Transaction memory _userTx,
        OperationsLib.Transaction memory _makerTx
    ) external view returns (bool) {
        // address spvAddress = getManager.getSPV();

        //1. _makerTx is already spv
        // TODO:
        // bool txVerify = IORSpv(spvAddress).verifyMakerTxProof(_makerTx, _makerProof);
        // require(txVerify, "MCE_UNVERIFY");
        (, , , uint256 maxDisputeTime, , , ) = getManager.getChain(_userTx.chainId);
        // The transaction time of maker is required to be later than that of user.
        // At the same time, the time difference between the above two times is required to be less than the maxDisputeTime.
        require(
            _makerTx.timestamp - _userTx.timestamp > 0 && _makerTx.timestamp - _userTx.timestamp < maxDisputeTime,
            "MCE_TIMEINVALIDATE"
        );
        return true;
    }
}
