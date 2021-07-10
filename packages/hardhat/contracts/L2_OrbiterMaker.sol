// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        uint256 availableDepositAmount;
        uint256 fee;
        uint256 minQuota;
        uint256 maxQuota;
        uint256 chainID;
        uint256 startTimeStamp;
    }
    /**
      certificate
     */
    // Proof of repayment， create by
    struct RepaymentProof {
        address fromAddress; // coinDealer
        address toAddress;
        address tokenAddress;
        uint256 amount;
        uint256 timestamp;
        uint256 chainID;
        bytes32 proofID;
    }

    // Proof of FreezeDeposit
    struct FreezeDepositProof {
        uint256 freezeAmount;
        bool isFreeze;
    }
    //The state of the coin dealer（0:Not Coin Dealer 1:Coin Dealer 2:stop
    // accountAddress =>(tokenAddress => state)
    mapping(address => mapping(address => uint256)) public CoinDealerState;
    // accountAddress =>(tokenAddress => DepositProof)
    mapping(address => mapping(address => DepositProof)) public CoinDealerInfo;
    // coinDealer => proofID => FreezeDepositProof
    mapping(address => mapping(bytes32 => FreezeDepositProof))
        public CoinDealerFreezeDepositInfo;

    // accountAddress =>(tokenAddress => withDrawTime)
    mapping(address => mapping(address => uint256)) public WithDrawTimes;
    // accountAddress =>(tokenAddress => stopButtferTime)
    // The time when the coinDealer actually stops trading
    mapping(address => mapping(address => uint256)) public stopTimes;

    // key(proofID)(uint256) => how to generate
    mapping(bytes32 => RepaymentProof) public RepaymentData;

    // Repayer related （address = fromAddress = coinDealer）
    mapping(address => bytes32[]) public RepaymentFrom;

    // Borrower related (address = toAddress)
    mapping(address => bytes32[]) public RepaymentTo;

    uint256 L1CTCTime;
    uint256 pushManServerTime;
    uint256 stopBufferTime;

    function setParamTime(
        uint256 _L1CTCTime,
        uint256 _pushManServerTime,
        uint256 _stopBufferTime
    ) public onlyOwner {
        L1CTCTime = _L1CTCTime;
        pushManServerTime = _pushManServerTime;
        stopBufferTime = _stopBufferTime;
    }

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
        uint256 chainID,
        uint256 startTimeStamp
    ) public {
        require(account != address(0), "account can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        require(
            msg.sender == account,
            "register coinDealer account must be msg.sender"
        );
        // coinDealer transefer amount token to contranct ， balanceOf() should >= amount
        IERC20 depositToken = IERC20(tokenAddress);
        require(
            depositToken.balanceOf(msg.sender) >= amount,
            "The account must have tokens greater than the amount"
        );
        // minQuota   maxQuota   amount
        require(minQuota < maxQuota, "minQuota must be less than maxQuota");
        require(minQuota > 0, "minQuota can not be 0");
        require(maxQuota < amount, "maxQuota must be less than amount");
        // if coinDealer want to add depositAmount，should use another funciton（add？？？？）
        require(
            // ??????
            CoinDealerState[account][tokenAddress] == 0,
            "account & tokenAddress can not be coinDealer"
        );
        // coinDealer transfer token to Contract ??????
        // depositToken.approve(address(this), amount) ？？？？  front
        // console.log("coinDealerBalance =", depositToken.balanceOf(msg.sender));
        // console.log("contractBalance =", depositToken.balanceOf(address(this)));
        uint256 approveAmount = depositToken.allowance(
            msg.sender,
            address(this)
        );
        // console.log("approveAmount =", approveAmount, "amount =", amount);
        require(approveAmount == amount, "approveAmount must equal to amount");
        depositToken.transferFrom(msg.sender, address(this), amount);
        // generate DepositProof
        DepositProof memory newProof = DepositProof(
            account,
            tokenAddress,
            amount,
            amount,
            fee,
            minQuota,
            maxQuota,
            chainID,
            startTimeStamp
        );
        // transfer  success setCoinDealerInfo & setCoinDealerState
        CoinDealerInfo[msg.sender][tokenAddress] = newProof;
        CoinDealerState[msg.sender][tokenAddress] = 1;
    }

    /**
     * @dev Freeze the account availableDepositAmount
     * @param account The account to freeze availableDepositAmount  => coindealer
     * @param tokenAddress The token in which coinDealer cease business
     * @param amount The amount account shoule be freeze
     * @param proofID The proofID that shoule be freeze
     */
    function FreezeCoinDealerDepositAmount(
        address account,
        address tokenAddress,
        uint256 amount,
        bytes32 proofID
    ) public {
        require(account != address(0), "account can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        // msg.sender ==> ownalbe??
        // require(msg.sender == account, "account must be msg.sender");
        require(
            CoinDealerState[account][tokenAddress] == 1,
            "account & tokenAddress must be coinDealer and CoinDealerState[account][tokenAddress] must be 1"
        );
        require(
            CoinDealerFreezeDepositInfo[account][proofID].isFreeze == false &&
                CoinDealerFreezeDepositInfo[account][proofID].freezeAmount == 0,
            "This set of data has not been used"
        );
        DepositProof memory proof = CoinDealerInfo[account][tokenAddress];
        uint256 oldAvailableAmount = proof.availableDepositAmount;
        require(
            amount < oldAvailableAmount,
            "freezeAmount must be less than availableDepositAmount"
        );
        uint256 newAvailableAmount = oldAvailableAmount - amount;
        CoinDealerInfo[account][tokenAddress]
        .availableDepositAmount = newAvailableAmount;
        CoinDealerFreezeDepositInfo[account][proofID].isFreeze = true;
        CoinDealerFreezeDepositInfo[account][proofID].freezeAmount = amount;
    }

    /**
     * @dev UnFreeze the account availableDepositAmount
     * @param account The account to unfreeze availableDepositAmount  => coindealer
     * @param tokenAddress The token in which coinDealer cease business
     * @param unFreezeAmount The amount account shoule be unfreeze
     * @param proofID The proofID that shoule be freeze
     */
    function UnFreezeCoinDealerDepositAmount(
        address account,
        address tokenAddress,
        uint256 unFreezeAmount,
        bytes32 proofID
    ) public {
        require(account != address(0), "account can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        // msg.sender ==> ownalbe??
        // require(msg.sender == account, "account must be msg.sender");
        require(
            CoinDealerState[account][tokenAddress] != 0,
            "account & tokenAddress must be coinDealer"
        );
        DepositProof memory depositProof = CoinDealerInfo[account][
            tokenAddress
        ];

        FreezeDepositProof memory freezeProof = CoinDealerFreezeDepositInfo[
            account
        ][proofID];
        uint256 depositAmount = depositProof.depositAmount;
        uint256 oldAvailableAmount = depositProof.availableDepositAmount;
        uint256 FreezeDepositAmount = freezeProof.freezeAmount;
        require(
            freezeProof.isFreeze == true,
            "This set of data must has been used"
        );
        require(
            FreezeDepositAmount == unFreezeAmount,
            "unFreezeAmount must be equal to Stored frozen amount"
        );

        require(
            oldAvailableAmount + unFreezeAmount < depositAmount,
            "depositAmount must be less than oldAvailableAmount plus unFreezeAmount"
        );
        uint256 newAvailableAmount = oldAvailableAmount + unFreezeAmount;
        CoinDealerInfo[account][tokenAddress]
        .availableDepositAmount = newAvailableAmount;
        CoinDealerFreezeDepositInfo[account][proofID].isFreeze = false;
        CoinDealerFreezeDepositInfo[account][proofID].freezeAmount = 0;
    }

    /**
     * @dev get the account availableDepositAmount from Coin Dealer
     * @param account The account to get availableDepositAmount
     * @param tokenAddress The token in which coinDealer cease business
     */
    function getCoinDealeravailableDepositAmount(
        address account,
        address tokenAddress
    ) public returns (uint256) {
        require(account != address(0), "account can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        require(msg.sender == account, "account must be msg.sender");
        require(
            CoinDealerState[account][tokenAddress] != 0,
            "account & tokenAddress must be coinDealer"
        );
        DepositProof memory proof = CoinDealerInfo[account][tokenAddress];
        uint256 availableDepositAmount = proof.availableDepositAmount;
        return availableDepositAmount;
    }

    /**
     * @dev stop the account to be a Coin Dealer
     * @param account The account stop to be Coin Dealer
     * @param tokenAddress The token in which coinDealer cease business
     */
    function stopCoinDealer(address account, address tokenAddress) public {
        require(account != address(0), "account can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        require(
            msg.sender == account,
            "stop coinDealer account must be msg.sender"
        );
        // Determine whether the account is Coin Dealer and CoinDealerState must be 1
        require(
            CoinDealerState[account][tokenAddress] == 1,
            "account&tokenAddress must be Coin Dealer and CoinDealerState must be 1"
        );
        // ????????????????  || => &&
        // require(
        //     (L1CTCTime != 0 && pushManServerTime != 0) || stopBufferTime != 0,
        //     "L1CTCTime&pushManServerTime&stopBufferTime can not be false"
        // );
        // eg.  stopTimeStamp = now + 60 second （Buffer time is 60s）？？？？？？???
        uint256 stopTime = block.timestamp + stopBufferTime;
        uint256 withDrawTime = block.timestamp + L1CTCTime + pushManServerTime;
        console.log("stopTime =", stopTime);
        console.log("withDrawTime =", withDrawTime);
        // update CoinDealerState，and the coin Dealer cannot be traded
        CoinDealerState[account][tokenAddress] = 2;
        // setWithDrawTime
        WithDrawTimes[account][tokenAddress] = withDrawTime;
        // setStopTime
        stopTimes[account][tokenAddress] = stopTime;
        console.log("stopTime =", stopTimes[account][tokenAddress]);
        console.log("withDrawTime =", WithDrawTimes[account][tokenAddress]);
    }

    /**
     * @dev Flag withdrawal status
     * @param account The account(stop) will withDraw
     * @notice Call this method to mark the withdrawal status, and then you can call the method withDrawingCoinDealer to withdraw after withDrawTime
     */

    function withDrawCoinDealer(address account, address tokenAddress) public {
        require(account != address(0), "account can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        require(
            msg.sender == account,
            "withdraw coinDealer account must be msg.sender"
        );
        // Determine whether the account is Coin Dealer and CoinDealerState must be 2
        require(
            CoinDealerState[account][tokenAddress] == 2,
            "account&tokenAddress must be Coin Dealer and CoinDealerState must be 2"
        );
        require(
            WithDrawTimes[account][tokenAddress] != 0,
            "WithDrawTime can not be 0"
        );
        uint256 withDrawTime = WithDrawTimes[account][tokenAddress];
        // console.log("now =", block.timestamp);
        // console.log("withDrawTime =", withDrawTime);
        require(
            block.timestamp > withDrawTime,
            "The current time must be after the withdrawal time"
        );
        DepositProof memory proof = CoinDealerInfo[account][tokenAddress];
        uint256 withDrawAmount = proof.depositAmount;
        // console.log("withDrawAmount =", withDrawAmount);
        AccountLiquidation(account, tokenAddress, withDrawAmount);
    }

    /**
     * @dev Repayment from orbiterMaker，And generate repayment proof
     * @param fromAddress   fromAddress
     * @param toAddress  toAddress
     * @param tokenAddress tokenAddress
     * @param amount  toAddress
     * @param chainID  chainID
     * @param proofID  proofID
     */
    function RepaymentTokenByCoinDealer(
        address fromAddress,
        address toAddress,
        address tokenAddress,
        uint256 amount,
        uint256 chainID,
        bytes32 proofID // bytes32 proofID // key?
    ) public {
        require(
            CoinDealerState[fromAddress][tokenAddress] != 0,
            "fromAddress must be coinDealer"
        );
        require(fromAddress != address(0), "fromAddress can not be address(0)");
        require(toAddress != address(0), "fromAddress can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        require(msg.sender == fromAddress, "msg.senfer must be fromAddress");
        IERC20 RepaymentToken = IERC20(tokenAddress);
        // require(
        //     RepaymentToken.balanceOf(fromAddress) >= amount,
        //     "The fromAddress must have tokens greater than the amount"
        // );
        uint256 approveAmount = RepaymentToken.allowance(
            msg.sender,
            address(this)
        );
        // console.log("approveAmount =", approveAmount, "amount =", amount);
        require(approveAmount == amount, "approveAmount must equal to amount");
        RepaymentToken.transferFrom(fromAddress, toAddress, amount);
        // generate RepaymentData(RepaymentProof) / RepaymentFrom  / RepaymentTo
        RepaymentProof memory proof = RepaymentProof(
            fromAddress,
            toAddress,
            tokenAddress,
            amount,
            block.timestamp,
            chainID,
            proofID
        );
        RepaymentData[proofID] = proof;
        // Whether to store more data？？？？？？？？？？？
        RepaymentFrom[fromAddress].push(proofID);
        RepaymentTo[toAddress].push(proofID);
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
     * @param tokenAddress tokenAddress
     * @param amount    fromLoanProof
     * @param chainID   fromLoanProof
     * @param proofID   fromLoanProof(key)
     */
    function singleLoanLiquidation(
        address fromAddress,
        address toAddress,
        address tokenAddress,
        uint256 amount,
        uint256 chainID,
        bytes32 proofID
    )
        public
    // error ?????? uint256 timeStap // L1 userAccount transferTime (timestap must less than stopTimes[account][tokenAddress])
    {
        require(
            CoinDealerState[toAddress][tokenAddress] != 0,
            "toAddress & tokenAddress must be a CoinDealer and CoinDealerState can not be 0"
        );
        require(fromAddress != address(0), "fromAddress can not be address(0)");
        require(toAddress != address(0), "toAddress can not be address(0)");
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        // ????require(msg.sender == pushserverAddress,"msg.senfer must be pushserverAddress");
        // search RepamentProof from RepaymentData according to the proofID
        // Match to the repaymentProof，indicating that the payment has been made
        require(
            RepaymentData[proofID].fromAddress == address(0) &&
                RepaymentData[proofID].toAddress == address(0),
            "Match to the repaymentProof,The loan has been repaid"
        );
        // Did not match the repaymentProof，Make a singleLoanLiquidation
        // Find the deposit certificate and get  depositAmount
        DepositProof memory coinDealerProof = CoinDealerInfo[toAddress][
            tokenAddress
        ];
        uint256 oldAmount = coinDealerProof.depositAmount;

        // The amount of pledge deposit, the amount to be repaid and the amount of contract holdings to compared
        require(
            oldAmount >= amount,
            "depositAmount must be greater than loanAmount"
        );
        IERC20 LiquidationToken = IERC20(tokenAddress);
        require(
            LiquidationToken.balanceOf(address(this)) >= amount,
            "The contract must have tokens greater than the amount"
        );
        // Deposit funds transfer and change the deposit certificate
        if (LiquidationToken.transfer(fromAddress, amount)) {
            uint256 newAmount = oldAmount - amount;
            CoinDealerInfo[toAddress][tokenAddress].depositAmount = newAmount;
        }
    }

    /**
     * @dev Clearing All certificate， called by withDrawCoinDealer
     * @param account  LiquidationAddress
     * @param tokenAddress  tokenAddress
     * @param withDrawAmount   withDrawAmount
     */
    function AccountLiquidation(
        address account,
        address tokenAddress,
        uint256 withDrawAmount
    ) public {
        //  contract transefer withDrawAmount token to coindealer ， balanceOf() should >= amount
        IERC20 withDrawToken = IERC20(tokenAddress);
        require(
            withDrawToken.balanceOf(address(this)) >= withDrawAmount,
            "The contract must have tokens greater than the withDrawAmount"
        );
        withDrawToken.transfer(account, withDrawAmount);
        /*
          ？？？？？？？？？？？？？
          Is it necessary to change the deposit certificate
         */
        CoinDealerState[account][tokenAddress] = 0;
        WithDrawTimes[account][tokenAddress] = 0;
    }

    constructor() public // _L1CTCTime,
    // _pushManServerTime,
    // _stopBufferTime,
    {
        // L1CTCTime = _L1CTCTime;
        // pushManServerTime = _pushManServerTime;
        // stopBufferTime = _stopBufferTime;
    }
}
