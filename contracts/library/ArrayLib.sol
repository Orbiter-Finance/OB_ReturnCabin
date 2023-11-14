// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

library ArrayLib {
    function includes(uint256[] memory arr, uint256 element) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; ) {
            if (element == arr[i]) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }

    function arrayIncludes(uint256[] memory arr, uint256[] memory elements) internal pure returns (bool) {
        for (uint256 i = 0; i < elements.length; i++) {
            bool ic = false;
            for (uint256 j = 0; j < arr.length; ) {
                if (elements[i] == arr[j]) {
                    ic = true;
                    break;
                }
                unchecked {
                    j++;
                }
            }

            if (!ic) return false;

            unchecked {
                i++;
            }
        }
        return true;
    }

    function includes(address[] memory arr, address element) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; ) {
            if (element == arr[i]) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }

    function arrayIncludes(address[] memory arr, address[] memory elements) internal pure returns (bool) {
        for (uint256 i = 0; i < elements.length; i++) {
            bool ic = false;
            for (uint256 j = 0; j < arr.length; ) {
                if (elements[i] == arr[j]) {
                    ic = true;
                    break;
                }
                unchecked {
                    j++;
                }
            }

            if (!ic) return false;

            unchecked {
                i++;
            }
        }
        return true;
    }
}
