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

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    // Token = await ethers.getContractFactory("Token");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    coinDealerAccount = addr1.address;
    userAccount = addr2.address;
    tokenAddress = address(0x123);

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

    describe("getL1TransferInfo()", function () {
      it("Should be Obtain a certain transfer information on L1 through parameters(???) from iExtractor", async function () {

        await L1_PushManServerContract.connect(addr2).getL1TransferInfo(
          userAccount,
          coinDealerAccount,
          tokenAddress,
          amount
        );
        // expect get transfer information from L1
        expect(await myContract.purpose()).to.equal(newPurpose);
      });
    });

    describe("convertToLoanProof()", function () {
      it("Should be Convert the transfer information into a loanProof", async function () {
        // convertToLoanProof(
        //   TransferInfo info
        //   // Dismantling parameters ？？？？？
        // )
        /*
        This test requires preconditions
          1. getL1TransferInfo(userAccount, coinDealerAccount, amount)
       */

        await L1_PushManServerContract.connect(addr2).convertToLoanProof(
          userAccount,
          coinDealerAccount,
          tokenAddress,
          amount
        );

        // generate loanProof
        // expect(await myContract.purpose()).to.equal(newPurpose);
      });
    });

    describe("sendMessageToL2Orbiter()", function () {
      it("Should be Call the singleLoanLiquidation of OrbiterMaker.sol on L2 with the loanProof", async function () {

        await L1_PushManServerContract.connect(addr2).sendMessageToL2Orbiter(
          //proof????
          userAccount,
          coinDealerAccount,
          tokenAddress,
          amount
        );
        // expect(await myContract.purpose()).to.equal(newPurpose);
      });
    });

    describe("generateProofID()", function () {
      it("SGenerate loan certificate ID", async function () {

        await L1_PushManServerContract.generateProofID(
          userAccount,
          param1,
          param2,
        );
        // expect(await myContract.purpose()).to.equal(newPurpose);
      });
    });
  });
});