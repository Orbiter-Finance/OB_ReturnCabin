const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");
const { chain, times } = require("ramda");

use(solidity);

describe("Extractor_zk Test", function () {
  let L1_PushManServer;
  let L1_PushManServerContract;

  let ZK_Extractor;
  let ZK_ExtractorContract;

  let owner;
  let addr1;
  let addr2;
  let addrs;

  let coinDealerAccount;
  let userAccount;
  let tokenAddress;

  // test
  const ZK_chainID = 1011;
  const timeStamp = 321321321;
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
      ZK_Extractor = await ethers.getContractFactory("Extractor_zk");
      ZK_ExtractorContract = await ZK_Extractor.deploy(
        L1_PushManServerContract.address
      );
      L1_PushManServerContract.initiExtractorAddress(
        ZK_ExtractorContract.address,
        ZK_chainID
      );
    });
    it("Should deploy SimpleToken", async function () {
      const SimpleToken = await ethers.getContractFactory("YourContract");
      SimpleTokenContract = await SimpleToken.deploy();
      tokenAddress = SimpleTokenContract.address;
    });
  });
  describe("getTransactionLoanProof()", function () {
    it("Should be Obtain a certain transfer information on L1 from iExtractor_l1", async function () {
      const transferInfo = await ZK_ExtractorContract.connect(
        addr2
      ).getTransactionLoanProof(
        userAccount,
        coinDealerAccount,
        tokenAddress,
        timeStamp,
        amount,
        ZK_chainID
      );
      // function need set view to get returns
      // await L1_PushManServerContract.test(amount);
      console.log("transferInfo = ", transferInfo);
      expect(transferInfo.TransferFromAddress).to.equal(userAccount);
      expect(transferInfo.TransferToAddress).to.equal(coinDealerAccount);
      expect(transferInfo.TransferAmount).to.equal(amount);
      expect(transferInfo.TransferTimestamp).to.equal(timeStamp);
      expect(transferInfo.TransferChainID).to.equal(ZK_chainID);
      expect(transferInfo.proofID).to.equal(
        await ZK_ExtractorContract.generateProofID(
          userAccount,
          timeStamp,
          ZK_chainID
        )
      );
    });
  });

  describe("appeal()", function () {
    it("appeal from iExtractor_zk", async function () {
      await ZK_ExtractorContract.connect(addr2).appeal(
        userAccount,
        coinDealerAccount,
        tokenAddress,
        timeStamp,
        amount,
        ZK_chainID
      );
      await ZK_ExtractorContract.connect(addr2).appeal(
        userAccount,
        coinDealerAccount,
        tokenAddress,
        timeStamp,
        amount,
        ZK_chainID
      );
      // function need set view to get returns
      // await L1_PushManServerContract.test(amount);
    });
  });
});
