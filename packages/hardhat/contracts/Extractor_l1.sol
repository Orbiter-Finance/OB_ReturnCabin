pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/iExtractor"

contract Extractor_l1 is iExtractor, Ownable {
    constructor(
    ) public {
    }
    function iExtractorFunction(
        address fromAddress,
        address toAddress,
        uint256 amount,
    ) public view override return(
      // return transfer information
    ) {
      // return transfer information
    };
}
