// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat')

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const [owner] = await ethers.getSigners()

  console.log('owner.address =', owner.address)

  const erc20Token = await hre.ethers.getContractFactory('testERC20Token')
  const tokenManager = await erc20Token.deploy(
    'testzxy',
    'tz',
    6,
    100000000000000,
  )
  const token = await tokenManager.deployed()
  console.log('tokenAddress =', token.address)

  let fChainID = 1
  let tChainID = 1
  const OrbiterManager = await hre.ethers.getContractFactory('OrbiterManager')
  const orbiterManager = await OrbiterManager.deploy()
  await orbiterManager.deployed()

  console.log('orbiterManagerAddress =', orbiterManager.address)

  await orbiterManager.setChainInfo(fChainID, 10, 0)

  // const depositContractAddress = await orbiterManager.createDepositContract()
  // console.log('depositContractAddress =', depositContractAddress)

  const Strings = await hre.ethers.getContractFactory('Strings')
  const stringManager = await Strings.deploy()
  await stringManager.deployed()

  console.log('StringManagerAddress =', stringManager.address)

  const OrbiterProtocalV1 = await ethers.getContractFactory(
    'OrbiterProtocalV1',
    {
      libraries: {
        Strings: stringManager.address,
      },
    },
  )
  const orbiterProtocalV1 = await OrbiterProtocalV1.deploy(
    orbiterManager.address,
  )
  await orbiterProtocalV1.deployed()
  console.log('orbiterProtocalV1Address =', orbiterProtocalV1.address)

  // deploy l1_extractor
  await orbiterProtocalV1.createExtractorContract(
    fChainID,
    tokenManager.address,
  )

  // await orbiterManager.createDepositContract()
  const OrbiterMakerDeposit = await ethers.getContractFactory(
    'OrbiterMakerDeposit',
  )
  const orbiterMakerDeposit = await OrbiterMakerDeposit.deploy()
  await orbiterMakerDeposit.deployed()
  console.log('orbiterMakerDepositAddress =', orbiterMakerDeposit.address)

  await orbiterMakerDeposit.createLPInfo(
    fChainID,
    tChainID,
    tokenManager.address,
    tokenManager.address,
    tokenManager.address,
    10000000000,
    50000000,
    100000,
    6,
    3,
    orbiterProtocalV1.address,
    6,
  )

  await token.transfer(orbiterMakerDeposit.address, 10000000000)

  await orbiterMakerDeposit.LPAction(
    fChainID,
    tChainID,
    tokenManager.address,
    tokenManager.address,
    tokenManager.address,
  )

  await orbiterMakerDeposit.userChallengeAction(
    fChainID,
    0,
    tChainID,
    tokenManager.address,
    tokenManager.address,
    tokenManager.address,
    0,
  )

  await orbiterMakerDeposit.userChanllengeWithDraw(
    fChainID,
    0,
    tChainID,
    tokenManager.address,
    tokenManager.address,
    0,
    tokenManager.address,
  )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
