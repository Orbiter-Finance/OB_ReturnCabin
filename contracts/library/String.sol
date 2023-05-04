library String {
    function uintToFloatString(uint256 value, uint256 decimalPlaces) internal pure returns (string memory) {
        // Calculate the integer and decimal parts of the float separately
        uint256 integerPart = value / (10 ** decimalPlaces);
        uint256 decimalPart = value % (10 ** decimalPlaces);
        // Convert the integer part to a string
        string memory integerPartString = toString(integerPart);

        // If there is no decimal part, return just the integer part
        if (decimalPart == 0) {
            return integerPartString;
        }

        // Convert the decimal part to a string
        string memory decimalPartString = toString(decimalPart);

        // Pad the decimal part with leading zeros if necessary
        uint256 padding = decimalPlaces - bytes(decimalPartString).length;
        for (uint256 i = 0; i < padding; i++) {
            decimalPartString = string(abi.encodePacked(decimalPartString, "0"));
        }

        // Combine the integer and decimal parts to form the final float string
        return string(abi.encodePacked(integerPartString, ".", decimalPartString));
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        require(startIndex <= endIndex && endIndex <= strBytes.length, "Invalid start or end index");

        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }

        return string(result);
    }

    function parseInt(string memory str) internal pure returns (uint256) {
        bytes memory bstr = bytes(str);
        uint256 result = 0;
        for (uint i = 0; i < bstr.length; i++) {
            require(uint8(bstr[i]) >= 48 && uint8(bstr[i]) <= 57, "Non-numeric character encountered");
            result = result * 10 + (uint8(bstr[i]) - 48);
        }
        return result;
    }

    function removeTrailingZeros(string memory str) internal pure returns (string memory) {
        uint256 length = bytes(str).length;
        uint256 index = length;

        // Iterate from end of string to find first non-zero character
        while (index > 0) {
            index--;
            if (bytes(str)[index] != "0") {
                break;
            }
        }

        // If string contains only zeros, return "0"
        if (index == 0 && bytes(str)[0] == "0") {
            return "0";
        }

        // Slice string to remove trailing zeros
        return substring(str, 0, index + 1);
    }

    function getTrailingZerosIndex(string memory str) internal pure returns (int) {
        uint256 length = bytes(str).length;
        uint256 index = length;

        // Iterate from end of string to find first non-zero character
        while (index > 0) {
            index--;
            if (bytes(str)[index] != "0") {
                break;
            }
        }

        // If string contains only zeros, return "0"
        if (index == 0 && bytes(str)[0] == "0") {
            return -1;
        }

        // Slice string to remove trailing zeros
        return int(index + 1);
    }

    function bytesToString(bytes memory _bytes) internal pure returns (string memory) {
        uint256 bytesLength = _bytes.length;
        if (bytesLength == 0) {
            return "";
        }
        uint256 charCount = 0;
        uint256 j = 0;
        for (j = 0; j < bytesLength; j++) {
            if (_bytes[j] == bytes1(0)) {
                break;
            }
            charCount++;
        }
        bytes memory bytesArray = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesArray[j] = _bytes[j];
        }
        return string(bytesArray);
    }

}
