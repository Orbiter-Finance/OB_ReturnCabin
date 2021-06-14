
pragma solidity ^0.6.11;

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