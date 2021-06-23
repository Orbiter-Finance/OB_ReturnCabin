pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/iExtractor.sol";

contract Extractor_l1 is iExtractor, Ownable {
    struct L1TransactionInfo {
        address TransferFromAddress;
        address TransferToAddress;
        address TransferTokenAddress;
        uint256 TransferAmount;
        uint256 TransferTimestamp;
        uint256 TransferChainID;
    }
    mapping(bytes32 => L1TransactionInfo) public transferInfos;

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
        uint256 chainID = 1;
        bytes32 proofID = "test";
        // bytes32 proofID = generateProofID(fromAddress, chainID, chainID);
        L1TransactionInfo memory transferInfo = transferInfos[proofID];
        return (
            transferInfo.TransferFromAddress,
            transferInfo.TransferToAddress,
            transferInfo.TransferTokenAddress,
            transferInfo.TransferAmount,
            transferInfo.TransferTimestamp,
            transferInfo.TransferChainID
        );
    }

    function setTransactionInfoInL1(
        address fromAddress,
        address toAddress,
        address tokenAddress,
        uint256 timestamp,
        uint256 amount,
        uint256 chainID
    ) external override {
        L1TransactionInfo memory transferInfo = L1TransactionInfo(
            fromAddress,
            toAddress,
            tokenAddress,
            amount,
            timestamp,
            chainID
        );
        // bytes32 proofID = generateProofID(
        //     transferInfo.TransferFromAddress,
        //     transferInfo.TransferTimestamp,
        //     transferInfo.TransferChainID
        // );
        bytes32 proofID = "test";
        transferInfos[proofID] = transferInfo;
    }

    function generateProofID(
        address fromAddress,
        uint256 param1,
        uint256 param2
    ) public view returns (bytes32) {
        // Need to adjust the number of bits according to the realization
        return
            (bytes32(uint256(fromAddress)) << 96) |
            (bytes32(param1) << 32) |
            bytes32(param2);
    }
}
