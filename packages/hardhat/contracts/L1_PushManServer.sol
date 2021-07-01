// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Extractor_l1.sol";

/// @title Obtain the transaction information of Rollup on the L1 network, and provide the functions of generating loan vouchers and initiating arbitration
/// @author Orbiter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract L1_PushManServer is Ownable {
    // Whether to obtain a large amount of transaction information and store it here
    // How to distinguish valid transaction information

    // chainID => iExtractorContractAddress
    mapping(uint256 => address) public iExtractorAddress;
    uint256 loanID;
    struct TransferInfo {
        address TransferFromAddress;
        address TransferToAddress;
        address TransferTokenAddress;
        uint256 TransferAmount;
        uint256 TransferTimestamp;
        uint256 TransferChainID;
    }

    function initiExtractorAddress(address _iExtractorAddress, uint256 chainID)
        public
        onlyOwner
    {
        iExtractorAddress[chainID] = _iExtractorAddress;
    }

    /**
     * @dev Convert the transfer information into a loanProof
     * @param fromAddress fromAddress
     * @param toAddress toAddress
     * @param tokenAddress tokenAddress
     * @param loanAmount loanAmount
     * @param chainID chainID
     */
    function loanTokenInL1(
        address fromAddress,
        address toAddress,
        address tokenAddress,
        uint256 loanAmount,
        uint256 chainID //returns (address, uint256)
    ) public {
        require(chainID == 1, "chainID must be equal to 1");
        require(
            iExtractorAddress[chainID] != address(0),
            "iExtractorAddress[chainID] must be init"
        );
        require(fromAddress != address(0), "fromAddress can not be address(0)");
        require(toAddress != address(0), "fromAddress can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        require(msg.sender == fromAddress, "msg.senfer must be fromAddress");
        IERC20 loanToken = IERC20(tokenAddress);
        uint256 approveAmount = loanToken.allowance(msg.sender, address(this));
        require(
            approveAmount == loanAmount,
            "approveAmount must equal to loanAmount"
        );
        loanToken.transferFrom(fromAddress, toAddress, loanAmount);
        Extractor_l1(iExtractorAddress[chainID]).setTransactionInfoInL1(
            fromAddress,
            toAddress,
            tokenAddress,
            loanAmount,
            block.timestamp,
            chainID,
            loanID
        );
        loanID++;
        // return (toAddress, loanID - 1);
    }

    /**
     * @dev Call the singleLoanLiquidation of OrbiterMaker.sol on L2 with the loanProof
     * @param fromAddress fromAddress
     * @param toAddress toAddress
     * @param chainID chainID
     * @param amount amount
     */
    function sendMessageToL2Orbiter(
        address fromAddress,
        address toAddress,
        address tokenAddress,
        uint256 amount,
        uint256 timeStamp,
        uint256 chainID,
        bytes32 proofID
    ) external {
        require(fromAddress != address(0), "fromAddress can not be address(0)");
        require(toAddress != address(0), "fromAddress can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        require(timeStamp != 0, "timeStamp can not 0");
        require(
            proofID !=
                0x0000000000000000000000000000000000000000000000000000000000000000,
            "proofID can not 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        console.log(
            "iExtractorAddress[",
            chainID,
            "]=",
            iExtractorAddress[chainID]
        );
        require(
            iExtractorAddress[chainID] != address(0),
            "iExtractorAddress[chainID] must be init"
        );
        require(
            iExtractorAddress[chainID] == msg.sender,
            "iExtractorAddress[chainID] must be equal to msg.sender"
        );
        console.log("=======================", msg.sender);
        console.log("fromAddress =", fromAddress);
        console.log("toAddress =", toAddress);
        console.log("tokenAddress =", tokenAddress);
        console.log("timeStamp =", timeStamp);
        console.log("chainID =", chainID);
        console.log("amount =", amount);
        console.logBytes32(proofID);
    }

    /**
     * @dev Generate loan certificate ID（proofID）
     * @param fromAddress  bytes32（0~20）
     * @param timestamp  bytes32（21~26）
     * @param chainID  bytes32（27~29）
     * @param nonce  bytes32（30~32）
     * @return bytes32
     */
    function generateProofID(
        address fromAddress,
        uint256 timestamp,
        uint256 chainID,
        uint256 nonce
    ) public view returns (bytes32) {
        // Need to adjust the number of bits according to the realization
        return
            (bytes32(uint256(fromAddress)) << 96) |
            (bytes32(timestamp) << 56) |
            (bytes32(chainID) << 32) |
            bytes32(nonce);
    }

    constructor() public {
        loanID = 1;
    }
}
