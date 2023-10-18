// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IORExtraTransfer} from "./interface/IORExtraTransfer.sol";

contract ORExtraTransfer is IORExtraTransfer, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // For native token transfer, Ext can be added to input data. Can be replaced this function
    function transferNative(address payable to, bytes calldata ext) external payable nonReentrant {
        ext;
        (bool success, ) = to.call{value: msg.value}("");
        require(success, "TF_ETH");
    }

    function transferErc20(IERC20 token, address to, uint amount, bytes calldata ext) external nonReentrant {
        ext;
        token.safeTransferFrom(msg.sender, to, amount);
    }

    function batchTransferNative(
        address payable[] calldata tos,
        uint[] calldata amounts,
        bytes[] calldata exts
    ) external payable nonReentrant {
        require(tos.length == amounts.length, "LF0");
        require(amounts.length == exts.length, "LF1");

        uint totalAmount = 0;
        for (uint i = 0; i < tos.length; i++) {
            totalAmount += amounts[i];

            (bool success, ) = tos[i].call{value: amounts[i]}("");
            require(success, "TF_ETH");
        }

        require(totalAmount == msg.value, "VI");
    }

    function batchTransferErc20(
        IERC20 token,
        address[] calldata tos,
        uint[] calldata amounts,
        bytes[] calldata exts
    ) external nonReentrant {
        require(tos.length == amounts.length, "LF0");
        require(amounts.length == exts.length, "LF1");

        for (uint i = 0; i < tos.length; i++) {
            token.safeTransferFrom(msg.sender, tos[i], amounts[i]);
        }
    }

    // Use 'batchTransferErc20' as much as possible, unless it's need to transfer multiple tokens.
    function batchTransferErc20WithTokens(
        IERC20[] calldata tokens,
        address[] calldata tos,
        uint[] calldata amounts,
        bytes[] calldata exts
    ) external nonReentrant {
        require(tos.length == amounts.length, "LF0");
        require(amounts.length == exts.length, "LF1");
        require(tokens.length == tos.length, "LF2");

        for (uint i = 0; i < tos.length; i++) {
            tokens[i].safeTransferFrom(msg.sender, tos[i], amounts[i]);
        }
    }
}
