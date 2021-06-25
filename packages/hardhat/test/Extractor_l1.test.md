const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");
const { chain, times } = require("ramda");

use(solidity);

describe("Extractor_l1 Test", function () {
  let L1_PushManServer;
  let L1_PushManServerContract;

  let L1_Extractor;
  let L1_ExtractorContract;

  let owner;
  let addr1;
  let addr2;
  let addrs;

  let coinDealerAccount;
  let userAccount;
  let tokenAddress;

  // test
  const L1_chainID = 1;
  const timeStamp = 123123123;
  const amountNum = 100 * 10 ** 18;
  const amount = "0x" + amountNum.toString(16);

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
    it("Should deploy L1_PushManServer", async function () {
      L1_PushManServer = await ethers.getContractFactory("L1_PushManServer");
      L1_PushManServerContract = await L1_PushManServer.deploy();
    });
    it("Should deploy L1_Extractor", async function () {
      L1_Extractor = await ethers.getContractFactory("Extractor_l1");
      L1_ExtractorContract = await L1_Extractor.deploy(
        L1_PushManServerContract.address
      );
      L1_PushManServerContract.initiExtractorAddress(
        L1_ExtractorContract.address,
        L1_chainID
      );
    });
    it("Should deploy SimpleToken", async function () {
      const SimpleToken = await ethers.getContractFactory("YourContract");
      SimpleTokenContract = await SimpleToken.deploy();
      tokenAddress = SimpleTokenContract.address;
    });
  });

  describe("setTransactionInfoInL1()", function () {
    it("setTransactionInfoInL1", async function () {
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
  describe("getTransactionLoanProof()", function () {
    it("Should be Obtain a certain transfer information on L1 from iExtractor_l1", async function () {
      const transferInfo = await L1_ExtractorContract.connect(
        addr2
      ).getTransactionLoanProof(userAccount, timeStamp, L1_chainID);
      // function need set view to get returns
      // await L1_PushManServerContract.test(amount);
      console.log("transferInfo = ", transferInfo);
      expect(transferInfo.TransferFromAddress).to.equal(userAccount);
      expect(transferInfo.TransferToAddress).to.equal(coinDealerAccount);
      expect(transferInfo.TransferAmount).to.equal(amount);
      expect(transferInfo.TransferTimestamp).to.equal(timeStamp);
      expect(transferInfo.TransferChainID).to.equal(L1_chainID);
      expect(transferInfo.proofID).to.equal(
        await L1_ExtractorContract.generateProofID(
          userAccount,
          timeStamp,
          L1_chainID
        )
      );
    });
  });

  describe("appeal()", function () {
    it("appeal from iExtractor_zk", async function () {
      await L1_ExtractorContract.connect(addr2).appeal(
        userAccount,
        timeStamp,
        L1_chainID
      );
      // function need set view to get returns
      // await L1_PushManServerContract.test(amount);
    });
  });
});
