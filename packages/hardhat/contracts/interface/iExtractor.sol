
pragma solidity ^0.6.11;


/// @title Responsible for the interface declaration contract that interacts with different Rollups
/// @author Orbiter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
interface iExtractor {
    //What parameters are needed to obtain transaction information on L1
    function iExtractorFunction(
        address fromAddress,
        address toAddress,
        uint256 amount,
    ) external return(
      // return transfer information
    );
}