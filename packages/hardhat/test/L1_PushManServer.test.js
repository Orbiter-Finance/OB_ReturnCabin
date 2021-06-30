const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");
const { chain, times } = require("ramda");

use(solidity);

describe("L1_PushManServer Test", function () {
  let L1_PushManServer;
  let L1_PushManServerContract;

  let Extractor_l1;
  let Extractor_l1Contract;

  let Extractor_zk;
  let Extractor_zkContract;

  let SimpleTokenContract;

  let owner;
  let addr1;
  let addr2;
  let addrs;

  let coinDealerAccount;
  let userAccount;
  let tokenAddress;
  let ZK_ExtractorAddress;
  let L1_ExtractorAddress;

  const ZK_chainID = 1011;
  const L1_chainID = 1;
  const amountNum = 100 * 10 ** 18;
  const amount = "0x" + amountNum.toString(16);
  const timestamp = 123456789;

  const nonce = 321;

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
      SimpleTokenContract = await SimpleToken.deploy();
      tokenAddress = SimpleTokenContract.address;

      const pa2 = await SimpleTokenContract.balanceOf(owner.address);
      // console.log("222 =", pa2.toString());
      SimpleTokenContract.transfer(userAccount, pa2);
    });
    it("Should deploy Extractor_zk", async function () {
      Extractor_zk = await ethers.getContractFactory("Extractor_zk");
      Extractor_zkContract = await Extractor_zk.deploy(
        L1_PushManServerContract.address
      );
      ZK_ExtractorAddress = Extractor_zkContract.address;
    });
    it("Should deploy Extractor_l1", async function () {
      Extractor_l1 = await ethers.getContractFactory("Extractor_l1");
      Extractor_l1Contract = await Extractor_l1.deploy(
        L1_PushManServerContract.address
      );
      L1_ExtractorAddress = Extractor_l1Contract.address;
    });
  });

  describe("initiExtractorAddress()", function () {
    it("initiExtractorAddress", async function () {
      const ZK_chainID = 1011;
      const L1_chainID = 1;

      expect(
        await L1_PushManServerContract.iExtractorAddress(ZK_chainID)
      ).to.equal("0x0000000000000000000000000000000000000000");
      expect(
        await L1_PushManServerContract.iExtractorAddress(L1_chainID)
      ).to.equal("0x0000000000000000000000000000000000000000");
      await L1_PushManServerContract.initiExtractorAddress(
        ZK_ExtractorAddress,
        ZK_chainID
      );
      await L1_PushManServerContract.initiExtractorAddress(
        L1_ExtractorAddress,
        L1_chainID
      );
      expect(
        await L1_PushManServerContract.iExtractorAddress(ZK_chainID)
      ).to.equal(ZK_ExtractorAddress);
      expect(
        await L1_PushManServerContract.iExtractorAddress(L1_chainID)
      ).to.equal(L1_ExtractorAddress);
    });
  });

  describe("loanTokenInL1()", function () {
    it("Borrow through the pushManServer contract on the L1 chain and generate a loan certificate and save it in the Extractor_l1 contract", async function () {
      SimpleTokenContract.connect(addr2).approve(
        L1_PushManServerContract.address,
        amount
      );
      const ts = await L1_PushManServerContract.connect(addr2).loanTokenInL1(
        userAccount,
        coinDealerAccount,
        tokenAddress,
        amount,
        L1_chainID,
        nonce
      );
      console.log("ts =", ts);
    });
  });

  // describe("sendMessageToL2Orbiter()", function () {
  //   it("Should be Call the singleLoanLiquidation of OrbiterMaker.sol on L2 with the loanProof", async function () {
  //     // ??? error how to call sendMessageToL2Orbiter from Extractor_l1Contract & Extractor_zkContract
  //     const zk_proof = await L1_PushManServerContract.generateProofID(
  //       userAccount,
  //       timestamp,
  //       ZK_chainID,
  //       nonce
  //     );
  //     // ？？？？ how to send message from Extractor_zkContract
  //     // await L1_PushManServerContract.sendMessageToL2Orbiter(
  //     // userAccount,
  //     // coinDealerAccount,
  //     // tokenAddress,
  //     // amount,
  //     // timestamp,
  //     // ZK_chainID,
  //     // zk_proof
  //     // );

  //     const l1_proof = await L1_PushManServerContract.generateProofID(
  //       userAccount,
  //       timestamp,
  //       L1_chainID,
  //       nonce
  //     );
  //     // ？？？？ how to send message from Extractor_l1Contract
  //     await L1_PushManServerContract.connect(
  //       Extractor_l1Contract
  //     ).sendMessageToL2Orbiter(
  //       userAccount,
  //       coinDealerAccount,
  //       tokenAddress,
  //       amount,
  //       timestamp,
  //       L1_chainID,
  //       l1_proof
  //     );
  //   });
  // });

  describe("generateProofID()", function () {
    it("Generate loan certificate ID", async function () {
      const proofID = await L1_PushManServerContract.generateProofID(
        tokenAddress,
        11111,
        2222,
        321
      );
      console.log("proofID =", proofID);

      expect(
        await L1_PushManServerContract.generateProofID(
          tokenAddress,
          11111,
          2222,
          nonce
        )
      ).to.equal(proofID);
    });
  });
});
