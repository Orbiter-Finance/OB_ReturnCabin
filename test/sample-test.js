const { expect } = require('chai')
const { ethers } = require('hardhat')
const { textSpanEnd } = require('typescript')
const web3 = require('web3')

// const { ethers } = require('hardhat')

// const { ethers } = require('ethers')

const test = require('../scripts/L1TxProof.js')

const zkTest = require('../scripts/ZKTxProof.js')

describe('OrbiterMakerDeposit', function () {
  it("Should return the new OrbiterMakerDeposit once it's changed", async function () {
    // const provethVerifier = await hre.ethers.getContractFactory(
    //   'ProvethVerifier',
    // )
    // const provethVerifierManager = await provethVerifier.deploy()
    // await provethVerifierManager.deployed()
    // console.log('contractAddress =', provethVerifierManager.address)

    let zkTestData = await zkTest()

    // const L1_Proventh = await hre.ethers.getContractFactory('L1_Proventh')
    // const L1_ProventhManager = await L1_Proventh.deploy()
    // await L1_ProventhManager.deployed()
    // console.log('contractAddress =', L1_ProventhManager.address)
    // let testData = await test()
    // // console.log('data =', testData)
    // let result = await L1_ProventhManager.testTxInfoHash(
    //   testData.txinfoRLP,
    //   testData.proof,
    //   testData.header,
    //   testData.rlpIndex,
    // )
    // console.log('result =', result)

    // const [owner, addr1, addr2] = await ethers.getSigners()

    // console.log('owner.address =', owner.address)
    // console.log('addr1.address =', addr1.address)
    // console.log('addr2.address =', addr2.address)

    // const erc20Token = await hre.ethers.getContractFactory('testERC20Token')
    // const tokenManager = await erc20Token.deploy(
    //   'testzxy',
    //   'tz',
    //   6,
    //   100000000000000,
    // )
    // const token = await tokenManager.deployed()
    // const balance = await token.balanceOf(owner.address)
    // console.log('balance =', balance)
    // console.log('tokenAddress =', token.address)

    // let fChainID = 1
    // let tChainID = 1

    // const OrbiterManager = await hre.ethers.getContractFactory('OrbiterManager')
    // const orbiterManager = await OrbiterManager.deploy()
    // await orbiterManager.deployed()

    // // const depositContractAddress = await orbiterManager.createDepositContract()
    // // console.log('depositContractAddress =', depositContractAddress)

    // const Strings = await hre.ethers.getContractFactory('Strings')
    // const stringManager = await Strings.deploy()
    // await stringManager.deployed()

    // const OrbiterProtocalV1 = await ethers.getContractFactory(
    //   'OrbiterProtocalV1',
    //   {
    //     libraries: {
    //       Strings: stringManager.address,
    //     },
    //   },
    // )
    // const orbiterProtocalV1 = await OrbiterProtocalV1.deploy(
    //   orbiterManager.address,
    // )
    // await orbiterProtocalV1.deployed()

    // // let orbiterMakerDeposit = await orbiterManager.createDepositContract()
    // // console.log('orbiterMakerDeposit =', orbiterMakerDeposit.address)

    // const OrbiterMakerDeposit = await ethers.getContractFactory(
    //   'OrbiterMakerDeposit',
    // )
    // const orbiterMakerDeposit = await OrbiterMakerDeposit.deploy()
    // await orbiterMakerDeposit.deployed()
    // console.log('orbiterMakerDepositAddress =', orbiterMakerDeposit.address)

    // // 1111111111111
    // await orbiterManager.setChainInfo(fChainID, 10, 0)

    // // 22222222
    // await orbiterMakerDeposit.createLPInfo(
    //   fChainID,
    //   tChainID,
    //   tokenManager.address,
    //   tokenManager.address,
    //   tokenManager.address,
    //   10000000000,
    //   50000000,
    //   100000,
    //   6,
    //   3,
    //   orbiterProtocalV1.address,
    //   6,
    // )
    // // 333333333333
    // await token.transfer(orbiterMakerDeposit.address, 10000000000)

    // // 444444
    // // transfer orbiterMakerDeposit ETH

    // // 555555
    // await orbiterMakerDeposit.LPAction(
    //   fChainID,
    //   tChainID,
    //   tokenManager.address,
    //   tokenManager.address,
    //   tokenManager.address,
    // )

    // // 66666666
    // // deploy l1_extractor
    // await orbiterProtocalV1.createExtractorContract(
    //   fChainID,
    //   tokenManager.address,
    // )

    // await orbiterMakerDeposit.userChallengeAction(
    //   fChainID,
    //   0,
    //   tChainID,
    //   tokenManager.address,
    //   tokenManager.address,
    //   tokenManager.address,
    //   0,
    // )

    // await orbiterMakerDeposit.makerChanllenge(
    //   fChainID,
    //   0,
    //   tChainID,
    //   1,
    //   tokenManager.address,
    //   tokenManager.address,
    //   tokenManager.address,
    //   0,
    // )

    // await orbiterMakerDeposit.userChanllengeWithDraw(
    //   fChainID,
    //   0,
    //   tChainID,
    //   tokenManager.address,
    //   tokenManager.address,
    //   0,
    //   tokenManager.address,
    // )

    // expect(await greeter.greet()).to.equal('Hola, mundo!')
  })
})
