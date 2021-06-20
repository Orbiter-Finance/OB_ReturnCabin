
pragma solidity ^0.6.11;


/// @title Responsible for the interface declaration contract that interacts with different Rollups
/// @author Orbiter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
interface iExtractor {
    //What parameters are needed to obtain transaction information on L1
    function getTransactionInfo(
        address fromAddress,
        address toAddress,
        uint256 amount,
    ) external returns(
      // return transaction information
      address,address,address,uint256,uint256,uint256
    );
      // address fromAddress;
      // address toAddress;
      // address TokenAddress;
      // uint256 amount;
      // uint256 timestamp;
      // uint256 chainID;
}