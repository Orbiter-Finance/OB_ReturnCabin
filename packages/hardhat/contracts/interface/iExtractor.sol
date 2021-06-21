// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

/// @title Responsible for the interface declaration contract that interacts with different Rollups
/// @author Orbiter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
interface iExtractor {
    //What parameters are needed to obtain transaction information on L1
    function getTransactionInfo(
        address fromAddress,
        address toAddress,
        address tokenAddress,
        uint256 amount
    )
        external
        view
        returns (
            // return transaction information
            address TransferFromAddress,
            address TransferToAddress,
            address TransferTokenAddress,
            uint256 TransferAmount,
            uint256 TransferTimestamp,
            uint256 TransferChainID
        );
}
