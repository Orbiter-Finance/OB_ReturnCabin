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
const {
  BigNumber
} = require("@ethersproject/bignumber");
const {
  map
} = require("ramda");

use(solidity);

describe("L2_OrbiterMaker Test", function () {
  let L2_OrbiterMaker;
  let L2_OrbiterMakerContract;

  let SimpleToken;
  let SimpleTokenContract;

  let owner;
  let addr1;
  let addr2;
  let addrs;

  let tokenAddress;

  let coinDealerAccount;
  let userAccount;

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
    it("Should deploy SimpleToken", async function () {
      SimpleToken = await ethers.getContractFactory("YourContract");

      SimpleTokenContract = await SimpleToken.deploy();

      tokenAddress = SimpleTokenContract.address;

      const pa1 = await SimpleTokenContract.balanceOf(coinDealerAccount);
      console.log("111 =", pa1.toString());
      const pa2 = await SimpleTokenContract.balanceOf(owner.address);
      console.log("222 =", pa2.toString());

      SimpleTokenContract.transfer(coinDealerAccount, pa2);
      const pa3 = await SimpleTokenContract.balanceOf(coinDealerAccount);
      console.log("333 =", pa3.toString());
      const pa4 = await SimpleTokenContract.balanceOf(owner.address);
      console.log("444 =", pa4.toString());
    });
  });

  /**
   * test L2_OrbiterMakerContract registerCoinDealer() function
   */
  describe("registerCoinDealer()", function () {
    it("Should be register addr1 to be a CoinDealer", async function () {
      SimpleTokenContract.connect(addr1).approve(
        L2_OrbiterMakerContract.address,
        BigNumber.from("10000000000000000000000") // 10000
      );

      const amount = BigNumber.from("10000000000000000000000"); // 10000
      const fee = 100;
      const minQuota = 100;
      const maxQuota = 1000;
      const chainID = 10001;
      const startTimeStamp = Date.parse(new Date()) / 1000;

      expect(
        await L2_OrbiterMakerContract.CoinDealerState(
          coinDealerAccount,
          tokenAddress
        )
      ).to.equal(0);
      // test owner or accout
      await L2_OrbiterMakerContract.connect(addr1).registerCoinDealer(
        coinDealerAccount,
        tokenAddress,
        amount,
        fee,
        minQuota,
        maxQuota,
        chainID,
        startTimeStamp
      );

      const coinDealerNum = await SimpleTokenContract.balanceOf(
        coinDealerAccount
      );

      console.log("coinDealer =", coinDealerNum.toString());
      const contractNum = await SimpleTokenContract.balanceOf(
        L2_OrbiterMakerContract.address
      );

      console.log("contract =", contractNum.toString());

      expect(
        await L2_OrbiterMakerContract.CoinDealerState(
          coinDealerAccount,
          tokenAddress
        )
      ).to.equal(1);

      const CoinDealerInfo = await L2_OrbiterMakerContract.CoinDealerInfo(
        coinDealerAccount,
        tokenAddress
      );
      console.log(CoinDealerInfo);
      expect(CoinDealerInfo.CoinDealerAddress).to.equal(coinDealerAccount);
      expect(CoinDealerInfo.depositAmount).to.equal(amount);
      expect(CoinDealerInfo.chainID).to.equal(chainID);
      expect(CoinDealerInfo.fee).to.equal(fee);
      expect(CoinDealerInfo.minQuota).to.equal(minQuota);
      expect(CoinDealerInfo.maxQuota).to.equal(maxQuota);
      expect(CoinDealerInfo.startTimeStamp).to.equal(startTimeStamp);
    });
  });

  /**
   * test L2_OrbiterMakerContract stopCoinDealer()function
   */
  // describe("stopCoinDealer()", function () {
  //   it("Should be stop addr1 to be a CoinDealer", async function () {
  //     // test owner or accout
  //     await L2_OrbiterMakerContract.connect(addr1).stopCoinDealer(
  //       coinDealerAccount,
  //       tokenAddress
  //     );

  //     expect(
  //       await await L2_OrbiterMakerContract.CoinDealerState(
  //         coinDealerAccount,
  //         tokenAddress
  //       )
  //     ).to.equal(2);

  //     /*
  //       stopCoinDealer() need Buffer time, test Buffer time < 5s
  //      */
  //   });
  // });

  /**
   * test L2_OrbiterMakerContract withDrawCoinDealer()function
   */
  // describe("withDrawCoinDealer()", function () {
  //   it("Should be Withdraw the deposit of coin Dealer", async function () {
  //     /*
  //       This test requires preconditions
  //         1. registerCoinDealer(coinDealerAccount)
  //         2. stopCoinDealer(coinDealerAccount)
  //      */

  //     /*
  //       This test will involve liquidation later
  //         1. AccountLiquidation
  //         2. Is withDraw amount correct？ Whether the withdrawal is successful？
  //      */

  //     const coinDealerNum = await SimpleTokenContract.balanceOf(
  //       coinDealerAccount
  //     );

  //     const depositNum = await SimpleTokenContract.balanceOf(
  //       L2_OrbiterMakerContract.address
  //     );
  //     expect(
  //       await L2_OrbiterMakerContract.CoinDealerState(
  //         coinDealerAccount,
  //         tokenAddress
  //       )
  //     ).to.equal(2);
  //     // test owner or accout
  //     // setTimeout(async function () {
  //     await L2_OrbiterMakerContract.connect(addr1).withDrawCoinDealer(
  //       coinDealerAccount,
  //       tokenAddress
  //     );
  //     expect(
  //       await L2_OrbiterMakerContract.CoinDealerState(
  //         coinDealerAccount,
  //         tokenAddress
  //       )
  //     ).to.equal(0);
  //     // }, 10000);
  //     expect(
  //       await SimpleTokenContract.balanceOf(L2_OrbiterMakerContract.address)
  //     ).to.equal(0);

  //     expect(await SimpleTokenContract.balanceOf(coinDealerAccount)).to.equal(
  //       coinDealerNum.add(depositNum)
  //     );

  //     // Whether to check CoinDealerInfo

  //     /*
  //       withDrawTimeStamp() need Buffer time, test Buffer time < 10s
  //       withDrawTimeStamp = now + L1CTCPackingTime + pushManTime？？？
  //      */
  //     // setTimeout(async function () {
  //     //   expect(
  //     //     await L2_OrbiterMakerContract.CoinDealerState[coinDealerAccount]
  //     //   ).to.equal(0);
  //     // }, 10000);
  //   });
  // });

  /**
   * test L2_OrbiterMakerContract RepaymentTokenByCoinDealer(）function
   */
  describe("RepaymentTokenByCoinDealer()", function () {
    it("Should be Repayment from CoinDealer, generate repayment proof", async function () {
      const repayMentAmount = BigNumber.from((100 * 10 ** 18).toString());
      const repayMentChainID = 1011;
      const proofIDText = "test";
      const proofID = ethers.utils.formatBytes32String(proofIDText);

      const coinDealerNum = await SimpleTokenContract.balanceOf(
        coinDealerAccount
      );

      console.log("coinDealerNum =", coinDealerNum.toString());

      const userAccountNum = await SimpleTokenContract.balanceOf(userAccount);

      console.log("userAccountNum =", userAccountNum.toString());

      SimpleTokenContract.connect(addr1).approve(
        L2_OrbiterMakerContract.address,
        repayMentAmount // 100
      );

      // test owner or accout
      await L2_OrbiterMakerContract.connect(addr1).RepaymentTokenByCoinDealer(
        coinDealerAccount,
        userAccount,
        tokenAddress,
        repayMentAmount,
        repayMentChainID,
        proofID
      );

      expect(await SimpleTokenContract.balanceOf(coinDealerAccount)).to.equal(
        coinDealerNum.sub(repayMentAmount)
      );

      expect(await SimpleTokenContract.balanceOf(userAccount)).to.equal(
        userAccountNum.add(repayMentAmount)
      );

      // Verify the generation of repayment proof
      const repayMentProof = await L2_OrbiterMakerContract.RepaymentData(
        proofID
      );
      console.log("repayMentProof =", repayMentProof);
      expect(repayMentProof.fromAddress).to.equal(coinDealerAccount);
      expect(repayMentProof.toAddress).to.equal(userAccount);
      expect(repayMentProof.tokenAddress).to.equal(tokenAddress);
      expect(repayMentProof.amount).to.equal(repayMentAmount);
      expect(repayMentProof.chainID).to.equal(repayMentChainID);
      expect(repayMentProof.proofID).to.equal(proofID);
      // Verify the RepaymentFrom / RepaymentTo
      // expect(
      //   await L2_OrbiterMakerContract.RepaymentFrom[coinDealerAccount][0]
      // ).to.equal(proofID);
      // expect(
      //   await L2_OrbiterMakerContract.RepaymentTo[userAccount][0]
      // ).to.equal(proofID);

      // Verify the approvel and transfer
      // expert let balanceNow = balanceFirst - repayMentAmount;
    });
  });

  /**
   * test L2_OrbiterMakerContract singleLoanLiquidation(）function
   */
  describe("singleLoanLiquidation()", function () {
    it("Should be Clearing of a single loan certificate, called by pushmanServer", async function () {
      const TokenAddress = "0x000";
      const loanAmount = 120;
      const loanChainID = 1;
      const proofID = 101111111;
      const loanTimeStamp = Date.parse(new Date()) / 1000;

      // test owner or accout
      await L2_OrbiterMakerContract.connect(addr2).singleLoanLiquidation(
        userAccount,
        coinDealerAccount,
        TokenAddress,
        loanAmount,
        loanTimeStamp,
        loanChainID,
        proofID
      );

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
  // describe("AccountLiquidation()", function () {
  //   it("Should be Clearing All certificate， called by withDrawCoinDealer", async function () {
  //     const amount = 100;

  //     // test owner or accout
  //     await L2_OrbiterMakerContract.AccountLiquidation(
  //       account,
  //       TokenAddress,
  //       amount
  //     );
  //     expect(
  //       await L2_OrbiterMakerContract.CoinDealerState[account][tokenAddress]
  //     ).to.equal(0);
  //     expect(
  //       await L2_OrbiterMakerContract.WithDrawTimes[account][tokenAddress]
  //     ).to.equal(0);

  //     /*
  //      f
  //      */

  //     // Because withDrawCoinDealer must be after stopCoinDealer
  //     // stopCoinDealer => stop Orders
  //     // liquidationTime = now + L1CTCPackingTime + pushManTime？？？
  //     // withDraw amount = depositAmount - Liquidation transfer out amount
  //     // update CoinDealerState = 0
  //   });
  // });
});