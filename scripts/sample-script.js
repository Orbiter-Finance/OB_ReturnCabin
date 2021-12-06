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

  const Operations = await hre.ethers.getContractFactory('Operations')
  const operations = await Operations.deploy()
  await operations.deployed()
  console.log('operations deployed to:', operations.address)

  const OrbiterMakerDeposit = await hre.ethers.getContractFactory(
    'OrbiterMakerDeposit',
  )
  const orbiterMakerDeposit = await OrbiterMakerDeposit.deploy()
  await orbiterMakerDeposit.deployed()
  console.log('orbiterMakerDeposit deployed to:', orbiterMakerDeposit.address)

  const OrbiterManager = await hre.ethers.getContractFactory('OrbiterManager')
  const orbiterManager = await OrbiterManager.deploy()
  await orbiterManager.deployed()
  console.log('orbiterManager deployed to:', orbiterManager.address)

  const OrbiterProtocalV1 = await hre.ethers.getContractFactory(
    'OrbiterProtocalV1',
  )
  const orbiterProtocalV1 = await OrbiterProtocalV1.deploy(
    orbiterManager.address,
  )
  await orbiterProtocalV1.deployed()
  console.log('orbiterProtocalV1 deployed to:', orbiterProtocalV1.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
