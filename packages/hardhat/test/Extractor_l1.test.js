const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");
const { chain } = require("ramda");

use(solidity);

describe("L1_PushManServer Test", function () {
  let L1_Extractor;
  let L1_ExtractorContract;

  let owner;
  let addr1;
  let addr2;
  let addrs;

  let coinDealerAccount;
  let userAccount;
  let tokenAddress;

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

  describe("deploy contract", function () {
    it("Should deploy L1_Extractor", async function () {
      L1_Extractor = await ethers.getContractFactory("Extractor_l1");
      L1_ExtractorContract = await L1_Extractor.deploy();
    });
    it("Should deploy SimpleToken", async function () {
      const SimpleToken = await ethers.getContractFactory("YourContract");
      SimpleTokenContract = await SimpleToken.deploy();
      tokenAddress = SimpleTokenContract.address;
    });
  });

  describe("setTransactionInfoInL1()", function () {
    it("setTransactionInfoInL1", async function () {
      const L1_chainID = 1;
      const timeStamp = 123123123;
      const amountNum = 100 * 10 ** 18;
      const amount = "0x" + amountNum.toString(16);
      await L1_ExtractorContract.setTransactionInfoInL1(
        userAccount,
        coinDealerAccount,
        tokenAddress,
        amount,
        timeStamp,
        L1_chainID
      );
    });
  });
  describe("getTransactionInfo()", function () {
    it("Should be Obtain a certain transfer information on L1 through parameters(???) from iExtractor", async function () {
      const amountNum = 100 * 10 ** 18;
      const amount = "0x" + amountNum.toString(16);
      const transferInfo = await L1_ExtractorContract.getTransactionInfo(
        userAccount,
        coinDealerAccount,
        tokenAddress,
        amount
      );
      // function need set view to get returns
      // await L1_PushManServerContract.test(amount);
      console.log("transferInfo = ", transferInfo);
      // expect(transferInfo.TransferFromAddress).to.equal(userAccount);
      // expect(transferInfo.TransferToAddress).to.equal(coinDealerAccount);
      // expect(transferInfo.TransferTokenAddress).to.equal(tokenAddress);
      // console.log(
      //   "getL1TransferInfo_TransferAmount =",
      //   transferInfo.TransferAmount.toString()
      // );
      // console.log(
      //   "getL1TransferInfo_TransferTimestamp =",
      //   transferInfo.TransferTimestamp.toString()
      // );
      // console.log(
      //   "getL1TransferInfo_TransferChainID =",
      //   transferInfo.TransferChainID.toString()
      // );
    });
  });
});
