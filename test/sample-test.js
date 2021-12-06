const { expect } = require('chai')
const { ethers } = require('hardhat')

describe('OrbiterMakerDeposit', function () {
  it("Should return the new OrbiterMakerDeposit once it's changed", async function () {
    let fChainID = 1
    let tChainID = 2

    const OrbiterManager = await hre.ethers.getContractFactory('OrbiterManager')
    const orbiterManager = await OrbiterManager.deploy()
    await orbiterManager.deployed()

    await orbiterManager.setChainInfo(fChainID, 10, 100)
    await orbiterManager.setChainInfo(tChainID, 20, 200)

    const OrbiterProtocalV1 = await ethers.getContractFactory(
      'OrbiterProtocalV1',
    )
    const orbiterProtocalV1 = await OrbiterProtocalV1.deploy(
      orbiterManager.address,
    )
    await orbiterProtocalV1.deployed()

    const OrbiterMakerDeposit = await ethers.getContractFactory(
      'OrbiterMakerDeposit',
    )
    const orbiterMakerDeposit = await OrbiterMakerDeposit.deploy()
    await orbiterMakerDeposit.deployed()

    await orbiterMakerDeposit.createLPInfo(
      fChainID,
      tChainID,
      orbiterProtocalV1.address,
      orbiterProtocalV1.address,
      orbiterProtocalV1.address,
      100,
      50,
      1,
      20,
      3,
      orbiterProtocalV1.address,
    )

    // await orbiterProtocalV1.testMatch(1, 1000009001)

    // console.log(
    //   'test =',
    //   await orbiterMakerDeposit.getpool(
    //     fChainID,
    //     tChainID,
    //     orbiterProtocalV1.address,
    //     orbiterProtocalV1.address,
    //   ),
    // )
    // expect(await greeter.greet()).to.equal('Hola, mundo!')
  })
})
