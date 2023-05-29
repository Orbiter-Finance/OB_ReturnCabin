// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

library ArrayLib {
    function addressIncludes(address[] memory arr, address element) internal pure returns (bool) {
        for (uint i = 0; i < arr.length; ) {
            if (element == arr[i]) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }

    function addressArrayIncludes(address[] memory arr, address[] memory elements) internal pure returns (bool) {
        for (uint i = 0; i < elements.length; i++) {
            bool includes = false;
            for (uint j = 0; j < arr.length; ) {
                if (elements[i] == arr[j]) {
                    includes = true;
                    break;
                }
                unchecked {
                    j++;
                }
            }

            if (!includes) return false;

            unchecked {
                i++;
            }
        }
        return true;
    }
}
