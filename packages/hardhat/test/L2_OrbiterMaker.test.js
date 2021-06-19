const {
  ethers
} = require("hardhat");
const {
  use,
  expect
} = require("chai");
const {
  solidity
} = require("ethereum-waffle");

use(solidity);



describe("L2_OrbiterMaker Test", function () {
  let L2_OrbiterMaker;
  let L2_OrbiterMakerContract;

  let owner;
  let addr1;
  let addr2;
  let addrs;

  let coinDealerAccount;
  let userAccount;




  const [owner, addr1] = await ethers.getSigners();

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    // Token = await ethers.getContractFactory("Token");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    coinDealerAccount = addr1.address;
    userAccount = addr2.address;

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    // hardhatToken = await Token.deploy();
  });

  /**
   * test L2_OrbiterMakerContract deploy
   */
  describe("deploy contract", function () {
    it("Should deploy L2_OrbiterMaker", async function () {
      L2_OrbiterMaker = await ethers.getContractFactory("L2_OrbiterMaker");

      L2_OrbiterMakerContract = await L2_OrbiterMaker.deploy();
    });
  });


  /**
   * test L2_OrbiterMakerContract registerCoinDealer() function
   */
  describe("registerCoinDealer()", function () {
    it("Should be register addr1 to be a CoinDealer", async function () {
      let amount = 10000;
      let fee = 100;
      let minQuota = 100;
      let maxQuota = 1000;
      let chainID = [0, 1];
      let startTimeStamp = Date.parse(new Date()) / 1000;

      expect(await L2_OrbiterMakerContract.CoinDealerState[coinDealerAccount]).to.equal(0);
      // test owner or accout
      await L2_OrbiterMakerContract.connect(addr1).registerCoinDealer(
        coinDealerAccount,
        amount,
        fee,
        minQuota,
        maxQuota,
        chainID,
        startTimeStamp
      );

      expect(await L2_OrbiterMakerContract.CoinDealerState[coinDealerAccount]).to.equal(1);
      expect(await L2_OrbiterMakerContract.CoinDealerInfo[coinDealerAccount].CoinDealerAddress).to.equal(coinDealerAccount);
      expect(await L2_OrbiterMakerContract.CoinDealerInfo[coinDealerAccount].depositAmount).to.equal(amount);
      expect(await L2_OrbiterMakerContract.CoinDealerInfo[coinDealerAccount].chainID[0]).to.equal(chainID[0]);
      expect(await L2_OrbiterMakerContract.CoinDealerInfo[coinDealerAccount].chainID[1]).to.equal(chainID[1]);
      expect(await L2_OrbiterMakerContract.CoinDealerInfo[coinDealerAccount].fee).to.equal(fee);
      expect(await L2_OrbiterMakerContract.CoinDealerInfo[coinDealerAccount].minQuota).to.equal(minQuota);
      expect(await L2_OrbiterMakerContract.CoinDealerInfo[coinDealerAccount].maxQuota).to.equal(maxQuota);
      expect(await L2_OrbiterMakerContract.CoinDealerInfo[coinDealerAccount].startTimeStamp).to.equal(startTimeStamp);
    });
  });

  /**
   * test L2_OrbiterMakerContract stopCoinDealer()function
   */
  describe("stopCoinDealer()", function () {
    it("Should be stop addr1 to be a CoinDealer", async function () {
      let stopTimeStamp = Date.parse(new Date()) / 1000;
      // test owner or accout
      await L2_OrbiterMakerContract.connect(addr1).stopCoinDealer(coinDealerAccount, stopTimeStamp);

      expect(await L2_OrbiterMakerContract.CoinDealerState[coinDealerAccount]).to.equal(1);


      /*
        stopCoinDealer() need Buffer time, test Buffer time < 5s
       */
      setTimeout(function () {
        expect(await L2_OrbiterMakerContract.CoinDealerState[coinDealerAccount]).to.equal(2);
      }, 5000)
    });
  });

  /**
   * test L2_OrbiterMakerContract withDrawCoinDealer()function
   */
  describe("withDrawCoinDealer()", function () {
    it("Should be Withdraw the deposit of coin Dealer", async function () {
      /*
        This test requires preconditions
          1. registerCoinDealer(coinDealerAccount)
          2. stopCoinDealer(coinDealerAccount)
       */

      /*
        This test will involve liquidation later
          1. AccountLiquidation
          2. Is withDraw amount correct？ Whether the withdrawal is successful？
       */

      let withDrawTimeStamp = Date.parse(new Date()) / 1000;
      // test owner or accout
      await L2_OrbiterMakerContract.connect(addr1).withDrawCoinDealer(coinDealerAccount, withDrawTimeStamp);

      expect(await L2_OrbiterMakerContract.CoinDealerState[coinDealerAccount]).to.equal(1);
      // Whether to check CoinDealerInfo

      /*
        withDrawTimeStamp() need Buffer time, test Buffer time < 10s
        withDrawTimeStamp = now + L1CTCPackingTime + pushManTime？？？
       */
      setTimeout(function () {
        expect(await L2_OrbiterMakerContract.CoinDealerState[coinDealerAccount]).to.equal(0);
      }, 10000)
    });
  });

  /**
   * test L2_OrbiterMakerContract RepaymentTokenByCoinDealer(）function
   */
  describe("RepaymentTokenByCoinDealer()", function () {
    it("Should be Repayment from CoinDealer, generate repayment proof", async function () {
      let TokenAddress = "0x000";
      let repayMentAmount = 120;
      let repayMentChainID = 1;
      let proofID = 101111111;
      let repayMentTimeStamp = Date.parse(new Date()) / 1000;

      // need use TokenAddress to get the balance of CoinDealer????
      let balanceFirst = 1000; //????
      // test owner or accout
      await L2_OrbiterMakerContract.connect(addr1).RepaymentTokenByCoinDealer(
        coinDealerAccount,
        userAccount,
        TokenAddress,
        repayMentAmount,
        repayMentTimeStamp,
        repayMentChainID,
        proofID);

      // Verify the generation of repayment proof
      expect(await L2_OrbiterMakerContract.RepaymentData[proofID].fromAddress).to.equal(coinDealerAccount);
      expect(await L2_OrbiterMakerContract.RepaymentData[proofID].toAddress).to.equal(userAccount);
      expect(await L2_OrbiterMakerContract.RepaymentData[proofID].TokenAddress).to.equal(TokenAddress);
      expect(await L2_OrbiterMakerContract.RepaymentData[proofID].amount).to.equal(repayMentAmount);
      expect(await L2_OrbiterMakerContract.RepaymentData[proofID].timestamp).to.equal(repayMentTimeStamp);
      expect(await L2_OrbiterMakerContract.RepaymentData[proofID].chainID).to.equal(repayMentChainID);
      expect(await L2_OrbiterMakerContract.RepaymentData[proofID].proofID).to.equal(proofID);

      // Verify the RepaymentFrom / RepaymentTo
      expect(await L2_OrbiterMakerContract.RepaymentFrom[coinDealerAccount][0]).to.equal(proofID);
      expect(await L2_OrbiterMakerContract.RepaymentTo[userAccount][0]).to.equal(proofID);

      // Verify the approvel and transfer
      // expert let balanceNow = balanceFirst - repayMentAmount;
    });
  });

  /**
   * test L2_OrbiterMakerContract singleLoanLiquidation(）function
   */
  describe("singleLoanLiquidation()", function () {
    it("Should be Clearing of a single loan certificate, called by pushmanServer", async function () {
      let TokenAddress = "0x000";
      let loanAmount = 120;
      let loanChainID = 1;
      let proofID = 101111111;
      let loanTimeStamp = Date.parse(new Date()) / 1000;

      // test owner or accout
      await L2_OrbiterMakerContract.connect(addr2).singleLoanLiquidation(
        userAccount,
        coinDealerAccount,
        TokenAddress,
        loanAmount,
        loanTimeStamp,
        loanChainID,
        proofID);

      // Verify the generation of repayment proof
      // expect(await L2_OrbiterMakerContract.RepaymentData[proofID].fromAddress).to.equal(coinDealerAccount);
      // expect(await L2_OrbiterMakerContract.RepaymentData[proofID].toAddress).to.equal(userAccount);
      // expect(await L2_OrbiterMakerContract.RepaymentData[proofID].TokenAddress).to.equal(TokenAddress);
      // expect(await L2_OrbiterMakerContract.RepaymentData[proofID].amount).to.equal(repayMentAmount);
      // expect(await L2_OrbiterMakerContract.RepaymentData[proofID].timestamp).to.equal(repayMentTimeStamp);
      // expect(await L2_OrbiterMakerContract.RepaymentData[proofID].chainID).to.equal(repayMentChainID);
      // expect(await L2_OrbiterMakerContract.RepaymentData[proofID].proofID).to.equal(proofID);

      // Verify the RepaymentFrom / RepaymentTo
      // expect(await L2_OrbiterMakerContract.RepaymentFrom[coinDealerAccount][0]).to.equal(proofID);
      // expect(await L2_OrbiterMakerContract.RepaymentTo[userAccount][0]).to.equal(proofID);

      // Verify the approvel and transfer
      // expert let balanceNow = balanceFirst - repayMentAmount;
    });
  });

  /**
   * test L2_OrbiterMakerContract AccountLiquidation(）function
   */
  describe("AccountLiquidation()", function () {
    it("Should be Clearing All certificate， called by withDrawCoinDealer", async function () {
      let amount = 100;

      // test owner or accout
      await L2_OrbiterMakerContract.AccountLiquidation(
        account,
        TokenAddress,
        amount
      );
      expect(await L2_OrbiterMakerContract.CoinDealerState[account][tokenAddress]).to.equal(0);
      expect(await L2_OrbiterMakerContract.WithDrawTimes[account][tokenAddress]).to.equal(0);

      /*
       f
       */

      // Because withDrawCoinDealer must be after stopCoinDealer
      // stopCoinDealer => stop Orders
      // liquidationTime = now + L1CTCPackingTime + pushManTime？？？
      // withDraw amount = depositAmount - Liquidation transfer out amount
      // update CoinDealerState = 0
    });
  });
});