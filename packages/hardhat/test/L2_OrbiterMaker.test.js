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
      const L2_OrbiterMaker = await ethers.getContractFactory("L2_OrbiterMaker");

      L2_OrbiterMakerContract = await L2_OrbiterMaker.deploy();
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

  });
});