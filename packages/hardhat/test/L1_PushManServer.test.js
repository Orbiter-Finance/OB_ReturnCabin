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

  describe("deploy contract", function () {
    it("Should deploy L1_PushManServer", async function () {
      const L1_PushManServer = await ethers.getContractFactory("L1_PushManServer");

      L1_PushManServer = await L1_PushManServer.deploy();
    });

    describe("setPurpose()", function () {
      it("Should be able to set a new purpose", async function () {
        const newPurpose = "Test Purpose";

        await myContract.setPurpose(newPurpose);
        expect(await myContract.purpose()).to.equal(newPurpose);
      });
    });
  });
});