# `contracts`

1. The smart contracts that power the Orbiter.
2. This project uses scaffold-eth, please refer to https://github.com/austintgriffith/scaffold-eth for basic usage

## Protocol Design

_For a detailed description of the protocol, please see the [whitepaper](https://docs.orbiter.finance/whitepaper_en)._

### Overview

### Contracts

**[L2_OrbiterMaker.sol](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/contracts/L2_OrbiterMaker.sol)** - Responsible for Arbitrum coin dealer registration, voucher processing, and clearing related logic

**[L1_PushManServer.sol](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/contracts/L1_PushManServer.sol)** - Obtain the transaction information of Rollup on the L1 network, and provide the functions of generating loan vouchers and initiating arbitration

**[Extractor_zk.sol](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/contracts/Extractor_zk.sol)** - Implementation of obtaining transaction information from zksync-rollups

**[Extractor_l1.sol](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/contracts/Extractor_l1.sol)** - Implementation of obtaining transaction information from l1

### [Test](https://github.com/OrbiterCross/V2-contracts/tree/main/packages/hardhat/test)

**[L1_PushManServer.test.js](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/test/L1_PushManServer.test.js)** - Test file of L1_PushManServer.sol

**[L2_OrbiterMaker.test.js](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/test/L2_OrbiterMaker.test.js)** - Test file of L2_OrbiterMaker.sol

**[Extractor_l1.test.js](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/test/Extractor_l1.test.js)** - Test file of L2_OrbiterMaker.sol

**[Extractor_zk.test.js](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/test/Extractor_zk.test.js)** - Test file of L2_OrbiterMaker.sol

### Definitions
