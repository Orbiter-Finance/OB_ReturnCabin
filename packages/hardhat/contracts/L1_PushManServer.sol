pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/iExtractor.sol"

/// @title Obtain the transaction information of Rollup on the L1 network, and provide the functions of generating loan vouchers and initiating arbitration
/// @author Orbiter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract L1_PushManServer is Ownable, iExtractor {
    // Whether to obtain a large amount of transaction information and store it here
    // How to distinguish valid transaction information
    constructor() public {}

    // chainID => iExtractorContractAddress
    mapping(uint256 => address)iExtractorAddress;

    // Proof of loan，create by L1PushManServer
    // struct LoanProof {
    //     address fromAddress;
    //     address toAddress;
    //     address TokenAddress;
    //     uint256 amount;
    //     uint256 timestamp;
    //     uint256 chainID;
    //     uint256 proofID;
    // }

    // transaction information，from L1CTC
    // struct TransferInfo {
    //     address fromAddress;
    //     address toAddress;
    //     address TokenAddress;
    //     uint256 amount;
    //     uint256 timestamp;
    //     uint256 chainID;
    //     uint256 proofID;
    // }

    function initiExtractorAddress (
        address _iExtractorAddress
    ) public onlyOwner{
      iExtractorAddress = _iExtractorAddress;
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
        uint256 chainID,
        uint256 amount
    ) internal returns (address,address,address,uint256,uint256,uint256) {
      require(iExtractorAddress[chainID] != address(0), "iExtractorAddress must be init");
      (address fromAddress,address toAddress,address TokenAddress,uint256 amount,uint256 timestamp,uint256 chainID) = iExtractor(iExtractorAddress).getTransactionInfo(fromAddress,toAddress,amount)
      // how to return a struct from function?????????
      // https://ethereum.stackexchange.com/questions/3609/returning-a-struct-and-reading-via-web3/3614#3614
      // return transfer information
      return(fromAddress, toAddress, TokenAddress, amount,timestamp, chainID)
    }

    /**
     * @dev Convert the transfer information into a loanProof
     * @param account The account being minted for
     * @param amount The amount being minted
     */
    function convertToLoanProof(
        address fromAddress,
        address toAddress,
        uint256 chainID,
        uint256 amount
    ) internal returns (address,address,address,uint256,uint256,uint256,uint256) {
      (address fromAddress,address toAddress,address TokenAddress,uint256 amount,uint256 timestamp,uint256 chainID) = getL1TransferInfo(fromAddress,toAddress,chainID,amount);
      // error  need change param?????
      uint256 proofID = generateProofID(toAddress,timestamp,chainID);
      return(fromAddress, toAddress, TokenAddress, amount,timestamp, chainID,proofID)

      // https://ethereum.stackexchange.com/questions/3609/returning-a-struct-and-reading-via-web3/3614#3614
      // return LoanProof
    }


    /**
     * @dev Call the singleLoanLiquidation of OrbiterMaker.sol on L2 with the loanProof
     * @param account The account being minted for
     * @param amount The amount being minted
     */
    function sendMessageToL2Orbiter(
        address fromAddress,
        address toAddress,
        uint256 chainID,
        uint256 amount,
    ) public {
      // require(Parameter verification )
      (address fromAddress,address toAddress,address TokenAddress,uint256 amount,uint256 timestamp,uint256 chainID,uint256 proofID) = convertToLoanProof(fromAddress, toAddress, chainID,amount)
      //Call singleLoanLiquidation of OrbiterMaker.sol on L2
      // 1.tickedid（？？ retry）
      // 2.Send directly (??)
    }


    /**
     * @dev Generate loan certificate ID（proofID）
     * @param fromAddress  bytes32（0~20）
     * @param param1  bytes32（21~28）
     * @param param2  bytes32（29~32）
     * @return bytes32
     */
    function generateProofID(
      address fromAddress,
      uint256 param1,
      uint256 param2)
    internal returns(bytes32){
      // Need to adjust the number of bits according to the realization
      return (bytes32(uint256(fromAddress)) << 96) | (bytes32(param1) << 32) | bytes(param2);
    }
}
