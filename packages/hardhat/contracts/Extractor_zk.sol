// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/iExtractor.sol";

// !!!importrant  ???
contract Extractor_zk is iExtractor {
    constructor() public {}

    function getTransactionInfo(
        address fromAddress,
        address toAddress,
        address tokenAddress,
        uint256 amount
    )
        external
        view
        override
        returns (
            address TransferFromAddress,
            address TransferToAddress,
            address TransferTokenAddress,
            uint256 TransferAmount,
            uint256 TransferTimestamp,
            uint256 TransferChainID
        )
    {
        console.log("Extractor_zk______Function");
        return (address(0x1), address(0x2), address(0x3), 1, 2, 1011);
    }
}
