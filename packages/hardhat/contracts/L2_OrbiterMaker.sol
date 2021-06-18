pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/// @title Responsible for Arbitrum coin dealer registration, voucher processing, and clearing related logic
/// @author Orbiter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract L2_OrbiterMaker is Ownable {
    /**
      CoinDealer
     */
     // proof of deposit，create by registerCoinDealer
    struct DepositProof {
        address CoinDealerAddress;
        address tokenAddress;
        uint256 depositAmount;
        uint256 fee;
        uint256 minQuota;
        uint256 maxQuota;
        uint256[] chainID;
        uint256 startTimeStamp;
    }
    //The state of the coin dealer（0:Not Coin Dealer 1:Coin Dealer 2:stop  3:withDraw）
    // accountAddress =>(tokenAddress => state)
    mapping(address => mapping(address => uint256)) public CoinDealerState;
    // accountAddress =>(tokenAddress => DepositProof)
    mapping(address => mapping(address => DepositProof)) public CoinDealerInfo;

    /**
     * @dev register the account to be anew Coin Dealer
     * @param account The account being Coin Dealer
     * @param tokenAddress The token in which coinDealer started business
     * @param amount The amount being Pledge
     * @param fee Transaction Fees
     * @param minQuota Minimum transaction limit
     * @param maxQuota Maximum transaction limit
     * @param chainID Supported L1 ChainID
     * @param startTimeStamp Do Coin Dealer start timestamp
     */
    function registerCoinDealer(
        address account,
        address tokenAddress,
        uint256 amount,
        uint256 fee,
        uint256 minQuota,
        uint256 maxQuota,
        uint256[] chainID,
        uint256 startTimeStamp
    ) public {
        require(account != address(0),"account can not be address(0)");
        require(tokenAddress != address(0),"tokenAddress can not be address(0)");
        require(msg.sender == account,"register coinDealer account must be msg.sender");

        // coinDealer transefer amount token to contranct ， balanceOf() should >= amount
        ERC20 depositToken = ERC20(tokenAddress);
        require(depositToken.balanceOf(msg.sender) >= amout,"The account must have tokens greater than the amount");

        // minQuota   maxQuota   amount
        require(minQuota < maxQuota,"minQuota must be less than maxQuota");
        require(minQuota > 0,"minQuota can not be 0");
        require(maxQuota < amount,"maxQuota must be less than amount");

        // if coinDealer want to add depositAmount，should use another funciton（add？？？？）
        require(CoinDealerState[account][tokenAddress] == 0,"account & tokenAddress can not be coinDealer");

        // generate DepositProof
        DepositProof memory newProof = DepositProof(account,tokenAddress,amount,fee,minQuota,maxQuota,chainID,startTimeStamp);

        // coinDealer transfer token to Contract
        // depositToken.approve(address(this), amount) ？？？？  front
        depositToken.transferFrom(msg.sender, address(this), amount);

        // transfer  success setCoinDealerInfo & setCoinDealerState
        CoinDealerInfo[msg.sender][tokenAddress] = newProof;
        CoinDealerState[msg.sender][tokenAddress] = 1;

        // Register coinDealer, generate proof of deposit
        //（minQuota maxQuota amount） Size judgment
        // amount
        // generate CoinDealerInfo , set CoinDealerInfo and CoinDealerState
    }

    /**
     * @dev stop the account to be a Coin Dealer
     * @param account The account stop to be Coin Dealer
     * @param tokenAddress The token in which coinDealer cease business
     * @param stopTimeStamp Do Coin Dealer start timestamp
     */
    function stopCoinDealer(address account, address tokenAddress,uint256 stopTimeStamp) public {
        require(account != address(0),"account can not be address(0)");
        require(tokenAddress != address(0),"tokenAddress can not be address(0)");
        require(msg.sender == account,"stop coinDealer account must be msg.sender");

        // Determine whether the account is Coin Dealer and CoinDealerState must be 1
        require(CoinDealerState[account][tokenAddress] == 1,"account&tokenAddress must be Coin Dealer and CoinDealerState must be 1");
        // eg.  stopTimeStamp = now + 60 second （Buffer time is 60s）？？？？？？
        // ????????????????
        // update CoinDealerState，and the coin Dealer cannot be traded
        CoinDealerState[account][tokenAddress] = 2;
    }

    /**
     * @dev Flag withdrawal status
     * @param account The account(stop) will withDraw
     * @notice Call this method to mark the withdrawal status, and then you can call the method withDrawingCoinDealer to withdraw after withDrawTime
     */

    function withDrawCoinDealer(address account, address tokenAddress)
        public
    {
        require(account != address(0),"account can not be address(0)");
        require(tokenAddress != address(0),"tokenAddress can not be address(0)");
        require(msg.sender == account,"withdraw coinDealer account must be msg.sender");


        // Determine whether the account is Coin Dealer and CoinDealerState must be 2
        require(CoinDealerState[account][tokenAddress] == 2,"account&tokenAddress must be Coin Dealer and CoinDealerState must be 2");
        // eg.  withDrawTimeStamp = now + L1CTCPackingTime + pushManTime？？？
        uint256 L1CTCTime = 3600 seconds;
        uint256 pushManServerTime = 3600 seconds;
        uint256 withDrawTime = now + L1CTCTime + pushManServerTime;
        // Where to store withDrawTime, so that it can be used when withdrawing?????
        /*
        ??????????????????????????????????
         */

        // setCoinDealerState = 3, withdrawingFunction will use it
        CoinDealerState[account][tokenAddress] == 3;
    }

     /**
     * @dev Withdraw the deposit of coin Dealer
     * @param account The account stop to be Coin Dealer
     * @notice before calling this function，must be call withDrawCoinDealer set CoinDealerState = 3 and Calculate withDrawTime
     */
    function withDrawingCoinDealer(address account, address tokenAddress)
        public
    {
        require(account != address(0),"account can not be address(0)");
        require(tokenAddress != address(0),"tokenAddress can not be address(0)");
        require(msg.sender == account,"withdrawing coinDealer account must be msg.sender");


        // Determine whether the account is Coin Dealer and CoinDealerState must be 3
        require(CoinDealerState[account][tokenAddress] == 3,"account&tokenAddress must be Coin Dealer and CoinDealerState must be 3");
        /*
          // where to get withDrawTime ???????????
         */
        uint256 withDrawTime = 12312312312312;

        require(now > withDrawTime, "The current time must be after the withdrawal time");
        DepositProof proof = CoinDealerInfo[account][tokenAddress];
        uint withDrawAmount = proof.depositAmount;
        //  contract transefer withDrawAmount token to coindealer ， balanceOf() should >= amount
        ERC20 withDrawToken = ERC20(tokenAddress);
        require(withDrawToken.balanceOf(address(this)) >= withDrawAmount,"The contract must have tokens greater than the withDrawAmount");
        withDrawToken.transfer(account,withDrawAmount);
        /*
          ？？？？？？？？？？？？？
          Is it necessary to change the deposit certificate
         */
        CoinDealerState[account][tokenAddress] = 0;
    }

    /**
      certificate
     */
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
        address fromAddress; // coinDealer
        address toAddress;
        address TokenAddress;
        uint256 amount;
        uint256 timestamp;
        uint256 chainID;
        uint256 proofID;
    }

    // key(proofID)(uint256) => how to generate
    mapping(bytes32 => RepaymentProof) public RepaymentData;

    // Repayer related （address = fromAddress = coinDealer）
    mapping(address => bytes32[]) public RepaymentFrom;

    // Borrower related (address = toAddress)
    mapping(address => bytes32[]) public RepaymentTo;

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
        address TokenAddress;
        uint256 amount,
        uint256 chainID
        // bytes32 proofID // key?
    ) public {
        require(CoinDealerState[fromAddress][tokenAddress] != 0,"fromAddress must be coinDealer");
        require(fromAddress != address(0),"fromAddress can not be address(0)");
        require(toAddress != address(0),"fromAddress can not be address(0)");
        require(tokenAddress != address(0),"tokenAddress can not be address(0)");
        require(msg.sender == fromAddress,"msg.senfer must be fromAddress");


        ERC20 RepaymentToken = ERC20(tokenAddress);
        require(RepaymentToken.balanceOf(fromAddress) >= amout,"The fromAddress must have tokens greater than the amount");
        // RepaymentToken.approve(address(this), amount) ？？？？  front
        RepaymentToken.transferFrom(fromAddress, toAddress, amount);
        // generate RepaymentData(RepaymentProof) / RepaymentFrom  / RepaymentTo
        // ？？？？？ how to get proofID(What data is used to generate proofID)
        bytes32 proofID = generateProofID(fromAddress,amount,chainID);
        RepaymentProof proof = RepaymentProof(fromAddress,toAddress,TokenAddress,amount,timestamp,chainID,proofID)
        RepaymentData[proofID] = proof;
        // Whether to store more data？？？？？？？？？？？
        RepaymentFrom[fromAddress].push(proofID);
        RepaymentTo[toAddress].push(proofID);
    }

    /**
     * @dev Generate RepayMent proof ID（proofID）
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
        address TokenAddress;
        uint256 amount,
        uint256 chainID,
        bytes32 proofID
    ) public {
        require(CoinDealerState[toAddress][tokenAddress] != 0,"toAddress must be coinDealer");
        require(fromAddress != address(0),"fromAddress can not be address(0)");
        require(toAddress != address(0),"toAddress can not be address(0)");
        require(tokenAddress != address(0),"tokenAddress can not be address(0)");
        // ????require(msg.sender == pushserverAddress,"msg.senfer must be pushserverAddress");

        // search RepamentProof from RepaymentData according to the proofID
        // Match to the repaymentProof，indicating that the payment has been made
        require(RepaymentData[proofID].fromAddress == address(0) && RepaymentData[proofID].toAddress == address(0),"Match to the repaymentProof");
        // Did not match the repaymentProof，Make a singleLoanLiquidation
        // Find the deposit certificate and get  depositAmount
        require(CoinDealerState[toAddress][TokenAddress] != 0,"toAddress & tokenAddress must be a CoinDealer and CoinDealerState can not be 0");
        DepositProof memory coinDealerProof = CoinDealerInfo[toAddress][TokenAddress];
        uint256 oldAmount = coinDealerProof.depositAmount;

        // The amount of pledge deposit, the amount to be repaid and the amount of contract holdings to compared
        require(oldAmount > amount, "depositAmount must be greater than repaymentAmount");
        ERC20 LiquidationToken = ERC20(tokenAddress);
        require(LiquidationToken.balanceOf(address(this)) >= amount,"The contract must have tokens greater than the amount");

        // Deposit funds transfer and change the deposit certificate
        if (LiquidationToken.transfer(fromAddress, amount)) {
            uint256 newAmount = oldAmount - amount;
            CoinDealerInfo[toAddress][TokenAddress].depositAmount = newAmount;
        }
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
        // withDrawing() equal
        // Because withDrawCoinDealer must be after stopCoinDealer
        //stopCoinDealer => stop Orders
        //liquidationTime = now + L1CTCPackingTime + pushManTime？？？
        // withDraw amount = depositAmount - Liquidation transfer out amount
        // update CoinDealerState = 0
    }
    constructor() public {}
}
