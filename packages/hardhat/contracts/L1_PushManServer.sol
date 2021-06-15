pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Obtain the transaction information of Rollup on the L1 network, and provide the functions of generating loan vouchers and initiating arbitration
/// @author Orbiter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract L1_PushManServer is Ownable {
    // Whether to obtain a large amount of transaction information and store it here
    // How to distinguish valid transaction information
    constructor() public {}

    // Proof of loan，create by L1PushManServer
    struct LoanProof {
        address fromAddress;
        address toAddress;
        // address TokenAddress;
        uint256 amount;
        uint256 timestamp;
        uint256 chainID;
        uint256 proofID;
    }

    // transaction information，from L1CTC
    struct TransferInfo {
        address fromAddress;
        address toAddress;
        // address TokenAddress;
        uint256 amount;
        uint256 timestamp;
        uint256 chainID;
        uint256 proofID;
    }

    /**
     * @dev Obtain a certain transfer information on L1 through parameters(???) from iExtractor
     * @param fromAddress The account being minted for
     * @param toAddress The amount being minted
     */
    //What parameters are needed to obtain transaction information on L1
    function getL1TransferInfo(
        address fromAddress,
        address toAddress,
        uint256 amount,
    ) public return(TransferInfo) {
      // how to return a struct from function?????????
      // https://ethereum.stackexchange.com/questions/3609/returning-a-struct-and-reading-via-web3/3614#3614
      // return transfer information
    }

    /**
     * @dev Convert the transfer information into a loanProof
     * @param account The account being minted for
     * @param amount The amount being minted
     */
    function convertToLoanProof(
        TransferInfo info
        // Dismantling parameters ？？？？？
    ) public return(LoanProof) {
      // how to return a struct from function?????????
      // https://ethereum.stackexchange.com/questions/3609/returning-a-struct-and-reading-via-web3/3614#3614
      // return LoanProof
    }


    /**
     * @dev Call the singleLoanLiquidation of OrbiterMaker.sol on L2 with the loanProof
     * @param account The account being minted for
     * @param amount The amount being minted
     */
    function sendMessageToL2Orbiter(
      LoanProof info
      // Dismantling parameters ？？？？？
    ) external {
      //Call singleLoanLiquidation of OrbiterMaker.sol on L2
    }
}
