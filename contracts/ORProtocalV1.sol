// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./library/StringLib.sol";
import "./interface/IORProtocal.sol";
import "./interface/IORManager.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

import {StrSlice, toSlice, StrChar, StrChar__} from "./stringutils/StrSlice.sol";
pragma solidity ^0.8.0;

contract ORProtocalV1 is IORProtocal, Initializable, OwnableUpgradeable {
    IORManager public getManager;
    OperationsLib.EBCConfigStruct public config;
    using {toSlice} for string;

    function initialize(address _manager, OperationsLib.EBCConfigStruct calldata _config) external initializer {
        require(_manager != address(0), "Owner address error");
        getManager = IORManager(_manager);
        config = _config;
        __Ownable_init();
    }

    function setConfig(OperationsLib.EBCConfigStruct calldata _config) external onlyOwner {
        config = _config;
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

    function getPledgedAmount(uint256 chainId, uint256 maxPrice) external view returns (uint256 value) {
        require(chainId != 0, "chain not exist");
        (, uint256 batchLimit, , , , ) = getManager.getChain(chainId);
        require(batchLimit != 0 && maxPrice != 0 && config.pledgeAmountSafeRate != 0, "PledgeAmountSafeRate Non Set");
        return ((batchLimit * maxPrice) * config.pledgeAmountSafeRate) / 10000;
    }

    function getPledgeAmount(
        uint256 batchLimit,
        uint256 maxPrice
    ) external view returns (uint256 baseValue, uint256 additiveValue) {
        require(batchLimit != 0 && maxPrice != 0 && config.pledgeAmountSafeRate != 0, "PledgeAmountSafeRate Non Set");
        baseValue = (batchLimit * maxPrice);
        additiveValue = (baseValue * config.pledgeAmountSafeRate) / 10000;
    }

    function calculateCompensation(
        address token,
        uint256 value
    ) external view returns (uint256 baseValue, uint256 additiveValue) {
        baseValue = value;
        if (token == address(0)) {
            additiveValue = (baseValue * config.mainCoinPunishRate) / 10000;
        } else {
            additiveValue = (baseValue * config.tokenPunishRate) / 10000;
        }
    }

    function getAmountValidDigits(string memory value, uint256 maxUint) internal view returns (uint256) {
        StrSlice strValue = value.toSlice();
        uint256 maxValue = maxUint < 256 ? 2 ** maxUint - 1 : type(uint256).max;
        StrSlice maxValueSlice = OperationsLib.uintToString(maxValue).toSlice();
        console.logString("maxValueSlice");
        console.logString(maxValueSlice.toString());
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
        (, , , , , uint256 maxUint) = getManager.getChain(chainKey);
        require(maxUint != 0, "Maximum bits not set");
        require(maxUint <= 256, "The maximum bits exceeds 256");
        StrSlice strValue = OperationsLib.uintToString(value).toSlice();
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

    function getSourceValueArgs(uint256 value) public pure returns (uint, uint, uint) {
        // get
        return StringLib.getSrouceValue3Args(value, 18);
    }

    function getToTxNonceId(OperationsLib.Transaction calldata _tx) public view returns (uint256) {
        (uint256 chainId, , , , , ) = getManager.getChain(_tx.chainId);
        require(chainId != 0, "chainId not set");
        string memory toChainId = getValueSecuirtyCode(chainId, _tx.value);
        uint256 code = OperationsLib.stringToUint(toChainId);
        return code;
    }

    function getResponseAmount(OperationsLib.Transaction calldata _tx) external view returns (uint256) {
        require(_tx.nonce <= 9999, "nonce too high, not allowed");
        uint gasFeeRate = 1000;
        uint tradingFee = 100000000000000;
        // usdt
        // uint tradingFee = 100000;
        // get pairId & lpInfo
        uint toAmountTradingFee = _tx.value - tradingFee;
        uint fee = (toAmountTradingFee * gasFeeRate) / 10000;
        // console.logString("getResponseAmount");
        // console.logUint(toAmountTradingFee);
        // console.logUint(fee);
        uint sendValue = toAmountTradingFee - fee;
        // console.logUint(sendValue);
        string memory nonce = OperationsLib.uintToString(_tx.nonce);
        for (uint i = nonce.toSlice().len(); i < 4; ) {
            nonce = string.concat("0", nonce);
            unchecked {
                ++i;
            }
        }
        // console.logString("nonce");
        // console.logString(nonce);
        StrSlice strValue = OperationsLib.uintToString(sendValue).toSlice();
        uint maxLen = strValue.len();
        require(maxLen > 4, "The length is too short");

        StrSlice afterStr = strValue.getSubslice(0, maxLen - 4);
        // console.logString("sub");
        // console.logUint(maxLen);
        // console.logString(afterStr.toString());
        string memory data = string.concat(afterStr.toString(), nonce);
        // console.logString(data);
        // return 9990000000000071;
        uint amount = OperationsLib.stringToUint(data);
        require(amount < _tx.value, "Amount calculation exception");
        return amount;
    }

    function getResponseAmountTest(
        OperationsLib.Transaction calldata _tx,
        uint gasFeeRate,
        uint tradingFee
    ) external view returns (uint256) {
        require(_tx.nonce <= 9999, "nonce too high, not allowed");
        // uint gasFeeRate = 1000;
        // uint tradingFee = 100000000000000;
        // usdt
        // uint tradingFee = 100000;
        // get pairId & lpInfo
        uint toAmountTradingFee = _tx.value - tradingFee;
        uint fee = (toAmountTradingFee * gasFeeRate) / 10 ** 18;
        console.logString("getResponseAmount");
        console.logUint(toAmountTradingFee);
        console.logUint(fee);
        uint sendValue = toAmountTradingFee - fee;
        console.logUint(sendValue);
        string memory nonce = OperationsLib.uintToString(_tx.nonce);
        for (uint i = nonce.toSlice().len(); i < 4; ) {
            nonce = string.concat("0", nonce);
            unchecked {
                ++i;
            }
        }
        console.logString("nonce");
        console.logString(nonce);
        StrSlice strValue = OperationsLib.uintToString(sendValue).toSlice();
        uint maxLen = strValue.len();
        require(maxLen > 4, "The length is too short");

        StrSlice afterStr = strValue.getSubslice(0, maxLen - 4);
        console.logString("sub");
        console.logUint(maxLen);
        console.logString(afterStr.toString());
        string memory data = string.concat(afterStr.toString(), nonce);
        console.logString(data);
        // return 9990000000000071;
        uint amount = OperationsLib.stringToUint(data);
        require(amount < _tx.value, "Amount calculation exception");
        return amount;
    }

    function getResponseHash(OperationsLib.Transaction calldata _tx, bool isSource) external view returns (bytes32) {
        if (isSource) {
            require(_tx.nonce < 9000, "nonce too high, not allowed");
            (uint chainId, , ) = StringLib.getSrouceValue3Args(_tx.value, 18);
            require(chainId != 0 && chainId >= 9000, "The chainId is incorrect");
            uint256 responseAmount = this.getResponseAmount(_tx);
            return keccak256(abi.encodePacked(_tx.from, _tx.to, chainId, _tx.nonce, responseAmount));
        } else {
            require(_tx.nonce <= 8999, "nonce too high, not allowed");
            require(_tx.chainId != 0, "The chainId is incorrect");
            uint256 fromNonce = this.getToTxNonceId(_tx);
            return keccak256(abi.encodePacked(_tx.to, _tx.from, _tx.chainId, fromNonce, _tx.value));
        }
    }

    function checkUserChallenge(uint256 value) external view returns (bool) {
        require(value >= config.challengePledgedAmount);
        return true;
    }

    function checkMakerChallenge(
        OperationsLib.Transaction memory _userTx,
        OperationsLib.Transaction memory _makerTx
    ) external view returns (bool) {
        (, , uint256 maxDisputeTime, , , ) = getManager.getChain(_userTx.chainId);
        // The transaction time of maker is required to be later than that of user.
        // At the same time, the time difference between the above two times is required to be less than the maxDisputeTime.
        require(
            _makerTx.timeStamp - _userTx.timeStamp > 0 && _makerTx.timeStamp - _userTx.timeStamp < maxDisputeTime,
            "MCE_TIMEINVALIDATE"
        );
        return true;
    }
}
