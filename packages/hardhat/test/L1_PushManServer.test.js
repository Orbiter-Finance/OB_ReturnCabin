const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");
const { chain } = require("ramda");

use(solidity);

describe("L1_PushManServer Test", function () {
  let L1_PushManServer;
  let L1_PushManServerContract;

  let owner;
  let addr1;
  let addr2;
  let addrs;

  let coinDealerAccount;
  let userAccount;
  let tokenAddress;
  let ExtractorAddress;

  let transferInfo;
  let LoanProof;

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
    it("Should deploy SimpleToken", async function () {
      const SimpleToken = await ethers.getContractFactory("YourContract");
      const SimpleTokenContract = await SimpleToken.deploy();
      tokenAddress = SimpleTokenContract.address;
      // const pa1 = await SimpleTokenContract.balanceOf(coinDealerAccount);
      // console.log("111 =", pa1.toString());
      // const pa2 = await SimpleTokenContract.balanceOf(owner.address);
      // console.log("222 =", pa2.toString());

      // SimpleTokenContract.transfer(coinDealerAccount, pa2);
      // const pa3 = await SimpleTokenContract.balanceOf(coinDealerAccount);
      // console.log("333 =", pa3.toString());
      // const pa4 = await SimpleTokenContract.balanceOf(owner.address);
      // console.log("444 =", pa4.toString());
    });
    it("Should deploy Extractor_zk", async function () {
      const Extractor_zk = await ethers.getContractFactory("Extractor_zk");
      const Extractor_zkContract = await Extractor_zk.deploy();
      ExtractorAddress = Extractor_zkContract.address;
      // const pa1 = await SimpleTokenContract.balanceOf(coinDealerAccount);
      // console.log("111 =", pa1.toString());
      // const pa2 = await SimpleTokenContract.balanceOf(owner.address);
      // console.log("222 =", pa2.toString());

      // SimpleTokenContract.transfer(coinDealerAccount, pa2);
      // const pa3 = await SimpleTokenContract.balanceOf(coinDealerAccount);
      // console.log("333 =", pa3.toString());
      // const pa4 = await SimpleTokenContract.balanceOf(owner.address);
      // console.log("444 =", pa4.toString());
    });
  });

  describe("initiExtractorAddress()", function () {
    it("initiExtractorAddress", async function () {
      const chainID = 1011;
      expect(
        await L1_PushManServerContract.iExtractorAddress(chainID)
      ).to.equal("0x0000000000000000000000000000000000000000");
      await L1_PushManServerContract.initiExtractorAddress(
        ExtractorAddress,
        chainID
      );
      expect(
        await L1_PushManServerContract.iExtractorAddress(chainID)
      ).to.equal(ExtractorAddress);
    });
  });

  describe("getL1TransferInfo()", function () {
    it("Should be Obtain a certain transfer information on L1 through parameters(???) from iExtractor", async function () {
      const chainID = 1011;
      const amountNum = 100 * 10 ** 18;
      const amount = "0x" + amountNum.toString(16);
      transferInfo = await L1_PushManServerContract.getL1TransferInfo(
        userAccount,
        coinDealerAccount,
        tokenAddress,
        chainID,
        amount
      );
      // function need set view to get returns
      // await L1_PushManServerContract.test(amount);
      console.log("transferInfo = ", transferInfo);
      expect(transferInfo.TransferFromAddress).to.equal(
        "0x0000000000000000000000000000000000000001"
      );
      expect(transferInfo.TransferToAddress).to.equal(
        "0x0000000000000000000000000000000000000002"
      );
      expect(transferInfo.TransferTokenAddress).to.equal(
        "0x0000000000000000000000000000000000000003"
      );
      expect(transferInfo.TransferAmount).to.equal(1);
      expect(transferInfo.TransferTimestamp).to.equal(2);
      expect(transferInfo.TransferChainID).to.equal(1011);
    });
  });

  describe("convertToLoanProof()", function () {
    it("Should be Convert the transfer information into a loanProof", async function () {
      LoanProof = await L1_PushManServerContract.connect(
        addr2
      ).convertToLoanProof(
        transferInfo.TransferFromAddress,
        transferInfo.TransferToAddress,
        transferInfo.TransferTokenAddress,
        transferInfo.TransferChainID,
        transferInfo.TransferAmount
      );
      console.log("loanProof =", LoanProof);
      expect(LoanProof.TransferFromAddress).to.equal(
        "0x0000000000000000000000000000000000000001"
      );
      expect(LoanProof.TransferToAddress).to.equal(
        "0x0000000000000000000000000000000000000002"
      );
      expect(LoanProof.TransferTokenAddress).to.equal(
        "0x0000000000000000000000000000000000000003"
      );
      expect(LoanProof.TransferAmount).to.equal(1);
      expect(LoanProof.TransferTimestamp).to.equal(2);
      expect(LoanProof.TransferChainID).to.equal(1011);
      expect(LoanProof.proofID).to.equal(
        await L1_PushManServerContract.connect(addr2).generateProofID(
          LoanProof.TransferFromAddress,
          LoanProof.TransferTimestamp,
          LoanProof.TransferChainID
        )
      );
    });
  });

  // describe("sendMessageToL2Orbiter()", function () {
  //   it("Should be Call the singleLoanLiquidation of OrbiterMaker.sol on L2 with the loanProof", async function () {
  //     await L1_PushManServerContract.connect(addr2).sendMessageToL2Orbiter(
  //       // proof????
  //       userAccount,
  //       coinDealerAccount,
  //       tokenAddress,
  //       amount
  //     );
  //     // expect(await myContract.purpose()).to.equal(newPurpose);
  //   });
  // });

  describe("generateProofID()", function () {
    it("Generate loan certificate ID", async function () {
      const proofID = await L1_PushManServerContract.generateProofID(
        LoanProof.TransferFromAddress, // 0x0000000000000000000000000000000000000001
        LoanProof.TransferTimestamp, // 2
        LoanProof.TransferChainID // 1011
      );
      console.log("proofID =", proofID);

      expect(
        await L1_PushManServerContract.generateProofID(
          "0x0000000000000000000000000000000000000001",
          2,
          1011
        )
      ).to.equal(proofID);
    });
  });
});
