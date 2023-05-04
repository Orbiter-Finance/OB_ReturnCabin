// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./library/Type.sol";
import "./library/String.sol";
import "hardhat/console.sol";
import "./interface/IEventBinding.sol";

contract EventBindingStandard is IEventBinding {
    using String for string;
    using String for uint;

    constructor() {}

    function getResponseResult(Types.Transaction memory _tx, Types.Pair memory pair) external view returns (bytes32) {
        bytes32 data;
        require(_tx.nonce <= 9999, "nonce too high, not allowed");
        (uint chainId, , ) = getSrouceValue3Args(_tx.value, 18);
        require(chainId != 0 && chainId >= 9000, "The chainId is incorrect");
        uint256 responseAmount = this.getResponseAmount(_tx);
        return keccak256(abi.encodePacked(_tx.from, _tx.to, chainId, _tx.nonce, responseAmount));
        return data;
    }

    function convertTxBytesToEntity() public returns (Types.Transaction memory data) {}

    function getSrouceValue3Args(
        uint value,
        uint decimalPlaces
    ) public pure returns (uint256 chainId, uint256 ebcId, uint256 dealerId) {
        uint256 decimalPart = value % (10 ** decimalPlaces);
        // Convert the integer part to a string
        // If there is no decimal part, return just the integer part
        if (decimalPart == 0) {
            return (0, 0, 0);
        }
        // Convert the decimal part to a string
        string memory decimalPartString = decimalPart.toString().removeTrailingZeros();

        bytes memory bstr = bytes(decimalPartString);

        decimalPartString = decimalPartString.substring(bstr.length - 4, bstr.length);
        uint maxLength = bytes(decimalPartString).length;
        require(maxLength == 4, "incorrect length");
        dealerId = decimalPartString.substring(0, 1).parseInt();
        chainId = decimalPartString.substring(1, 3).parseInt();
        ebcId = decimalPartString.substring(3, 4).parseInt();
    }

    function getResponseAmount(Types.Transaction calldata _tx) public view returns (uint256) {
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
        string memory nonce = _tx.nonce.toString();
        console.logString("hello");
        console.logString(nonce);
        // for (uint i = nonce.toSlice().len(); i < 4; ) {
        //     nonce = string.concat("0", nonce);
        //     unchecked {
        //         ++i;
        //     }
        // }
        // console.logString("nonce");
        // console.logString(nonce);
        // StrSlice strValue = OperationsLib.uintToString(sendValue).toSlice();
        // uint maxLen = strValue.len();
        // require(maxLen > 4, "The length is too short");

        // StrSlice afterStr = strValue.getSubslice(0, maxLen - 4);
        // // console.logString("sub");
        // // console.logUint(maxLen);
        // // console.logString(afterStr.toString());
        // string memory data = string.concat(afterStr.toString(), nonce);
        // // console.logString(data);
        // // return 9990000000000071;
        // uint amount = OperationsLib.stringToUint(data);
        // require(amount < _tx.value, "Amount calculation exception");
        // return amount;
    }
    
}
