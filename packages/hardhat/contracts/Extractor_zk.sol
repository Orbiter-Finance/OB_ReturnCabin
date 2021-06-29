// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./L1_PushManServer.sol";

// !!!importrant  ???
contract Extractor_zk {
    struct ZKLoanInfo {
        address LoanFromAddress;
        address LoanToAddress;
        address LoanTokenAddress;
        uint256 LoanAmount;
        uint256 LoanTimestamp;
        uint256 LoanChainID;
        bytes32 proofID;
    }

    address PushManServerAddress;

    constructor(address _pushManServerAddress) public {
        PushManServerAddress = _pushManServerAddress;
    }

    /**
     * @dev Obtain the loanProof on the L1 chain
     * @param fromAddress fromAddress
     * @param toAddress toAddress
     * @param tokenAddress tokenAddress
     * @param timestamp timestamp
     * @param amount amount
     * @param chainID chainID
     */
    function getTransactionLoanProof(
        address fromAddress,
        address toAddress,
        address tokenAddress,
        uint256 timestamp,
        uint256 amount,
        uint256 chainID,
        uint256 nonce
    )
        public
        view
        returns (
            address TransferFromAddress,
            address TransferToAddress,
            address TransferTokenAddress,
            uint256 TransferAmount,
            uint256 TransferTimestamp,
            uint256 TransferChainID,
            bytes32 proofID
        )
    {
        console.log(
            "come in Extractor_zk___getTransactionLoanProof___Function"
        );
        require(chainID == 1011, "zk_chainID must be 1011");
        bytes32 proofID = generateProofID(
            fromAddress,
            timestamp,
            chainID,
            nonce
        );
        return (
            fromAddress,
            toAddress,
            tokenAddress,
            amount,
            timestamp,
            chainID,
            proofID
        );
    }

    //
    function appeal(
        address fromAddress,
        address toAddress,
        address tokenAddress,
        uint256 timestamp,
        uint256 amount,
        uint256 chainID,
        uint256 nonce
    ) external {
        console.log("come in Extractor_zk___appeal___Function");
        require(chainID == 1011, "zk_chainID must be 1011");
        require(fromAddress != address(0), "fromAddress can not be address(0)");
        require(
            fromAddress == msg.sender,
            "fromAddress must equal to msg.sender"
        );
        require(toAddress != address(0), "toAddress can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        require(timestamp != 0, "timestamp can not 0");
        ZKLoanInfo memory loanInfo;
        (
            loanInfo.LoanFromAddress,
            loanInfo.LoanToAddress,
            loanInfo.LoanTokenAddress,
            loanInfo.LoanAmount,
            loanInfo.LoanTimestamp,
            loanInfo.LoanChainID,
            loanInfo.proofID
        ) = getTransactionLoanProof(
            fromAddress,
            toAddress,
            tokenAddress,
            timestamp,
            amount,
            chainID,
            nonce
        );
        L1_PushManServer(PushManServerAddress).sendMessageToL2Orbiter(
            loanInfo.LoanFromAddress,
            loanInfo.LoanToAddress,
            loanInfo.LoanTokenAddress,
            loanInfo.LoanAmount,
            loanInfo.LoanTimestamp,
            loanInfo.LoanChainID,
            loanInfo.proofID
        );
    }

    function generateProofID(
        address fromAddress,
        uint256 timestamp,
        uint256 chainID,
        uint256 nonce
    ) public view returns (bytes32) {
        // Need to adjust the number of bits according to the realization
        return
            (bytes32(uint256(fromAddress)) << 96) |
            (bytes32(timestamp) << 48) |
            (bytes32(chainID) << 24) |
            bytes32(nonce);
    }
}
