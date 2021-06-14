pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Responsible for Arbitrum coin dealer registration, voucher processing, and clearing related logic
/// @author Orbiter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract L2_OrbiterMaker is Ownable {
    /**
      CoinDealer
     */
    //The state of the coin dealer（0:Not Coin Dealer 1:Coin Dealer 2:stop）
    mapping(address => uint256) CoinDealerState;

    /**
     * @dev register the account to be anew Coin Dealer
     * @param account The account being Coin Dealer
     * @param amount The amount being Pledge
     * @param fee Transaction Fees
     * @param minQuota Minimum transaction limit
     * @param maxQuota Maximum transaction limit
     * @param chainID Supported L1 ChainID
     * @param startTimeStamp Do Coin Dealer start timestamp
     */
    function registerCoinDealer(
        address account,
        uint256 amount,
        uint256 fee,
        uint256 minQuota,
        uint256 maxQuota,
        uint256[] chainID,
        uint256 startTimeStamp
    ) public {
        // Register coinDealer, generate proof of deposit
        //（minQuota maxQuota amount） Size judgment
        // amount
    }

    /**
     * @dev stop the account to be a Coin Dealer
     * @param account The account stop to be Coin Dealer
     * @param stopTimeStamp Do Coin Dealer start timestamp
     */
    function stopCoinDealer(address account, uint256 stopTimeStamp) public {
        // Determine whether the account is Coin Dealer
        // eg.  stopTimeStamp = now + 60 second （Buffer time is 60s）？？？？？？
        // update CoinDealerState，and the coin Dealer cannot be traded
    }

    // /**
    //  * @dev stop the account to be a Coin Dealer
    //  * @param account The account stop to be Coin Dealer
    //  * @param stopTimeStamp Do Coin Dealer start timestamp
    //  */
    // function stopCoinDealer(address account, uint256 stopTimeStamp) public {
    //     // Determine whether the account is Coin Dealer
    //     // stopTimeStamp = now + 60 second （Buffer time is 60s）
    //     // update CoinDealerState = 2，and the coin Dealer cannot be traded
    // }

    /**
     * @dev Withdraw the deposit of coin Dealer
     * @param account The account stop to be Coin Dealer
     * @param withDrawTimeStamp Coin Dealer start timestamp
     */
    function withDrawCoinDealer(address account, uint256 withDrawTimeStamp)
        public
    {
        // Determine whether the account is Coin Dealer and CoinDealerState == 2
        // eg.  withDrawTimeStamp = now + L1CTCPackingTime + pushManTime？？？
        // Clearing logic to handle various vouchers(deposit,loan,Repayment)
        // withDraw amount = depositAmount - Liquidation transfer out amount
        // update CoinDealerState = 0
    }

    /**
      certificate
     */
    // proof of deposit，create by registerCoinDealer
    struct DepositProof {
        address CoinDealer;
        uint256 amount;
    }
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
    // Proof of repayment， create by
    struct RepaymentProof {
        address fromAddress;
        address toAddress;
        // address TokenAddress;
        uint256 amount;
        uint256 timestamp;
        uint256 chainID;
        uint256 proofID;
    }

    // key(proofID)(uint256) => how to generate
    mapping(address => mapping(uint256 => RepaymentProof)) RepaymentData;

    /**
     * @dev Repayment from orbiterMaker，And generate repayment proof
     * @param fromAddress
     * @param toAddress
     * @param amount
     * @param chainID
     * @param proofID
     */
    function RepaymentTokenByCoinDealer(
        address fromAddress,
        address toAddress,
        // address TokenAddress;
        uint256 amount,
        uint256 chainID,
        uint256 proofID // key?
    ) public {
        // Authorize the contract to process fromAddress's tokens, the contract transfers its tokens, and then generates a repayment proof
        // generate RepaymentData(RepaymentProof)??
        // Whether to store more data？？？？？？？？
    }

    // /**
    //  * @dev Repayment from pushMan or otherMaker, generate repayment proof
    //  * @param fromAddress
    //  * @param toAddress
    //  * @param amount
    //  * @param chainID
    //  * @param proofID
    //  */
    // function RepaymentTokenByPushMan(
    //     address fromAddress,
    //     address toAddress,
    //     // address TokenAddress;
    //     uint256 amount,
    //     uint256 chainID,
    //     uint256 proofID
    // ) public {
    //     // LoanProof is found according to the proofID, and it is determined that the LoanProof has not been processed
    //     // Here to judge whether the relevant information such as the amount, address, etc. is consistent
    //     // Authorize the contract to process fromAddress's tokens, the contract transfers its tokens, and then generates a repayment proof
    //     // Complex liquidation logic
    // }

    /**
      Liquidation
     */
    /**
     * @dev Clearing of a single loan certificate， called by pushmanServer
     * @param fromAddress  fromLoanProof
     * @param toAddress   fromLoanProof
     * @param amount    fromLoanProof
     * @param chainID   fromLoanProof
     * @param proofID   fromLoanProof(key)
     */
    function singleLoanLiquidation(
        address fromAddress,
        address toAddress,
        // address TokenAddress;
        uint256 amount,
        uint256 chainID,
        uint256 proofID(key)
    ) public {
        // Find RepamentProof from RepamentData according to the proofID
        // If RepamentProof is not found, enter the liquidation process
    }


    /**
     * @dev Clearing All certificate， called by withDrawCoinDealer
     * @param account  LiquidationAddress
     * @param liquidationTime   LiquidationTime
     */
    function AccountLiquidation(
        address account,
        uint liquidationTime
    ) public {
        // Because withDrawCoinDealer must be after stopCoinDealer
        //stopCoinDealer => stop Orders
        //liquidationTime = now + L1CTCPackingTime + pushManTime？？？
        // withDraw amount = depositAmount - Liquidation transfer out amount
        // update CoinDealerState = 0
    }
    constructor() public {}
}
