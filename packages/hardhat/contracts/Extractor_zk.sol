pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/iExtractor"

contract Extractor_zk is iExtractor, Ownable {
    constructor(
    ) public {
    }
    function getTransactionInfo(
        address fromAddress,
        address toAddress,
        uint256 amount,
    ) public view override return(
        address,address,address,uint256,uint256,uint256
    ) {
      // return transfer information
    };
}
