# `contracts`

1. The smart contracts that power the Orbiter.
2. This project uses scaffold-eth, please refer to https://github.com/austintgriffith/scaffold-eth for basic usage

## Protocol Design

_For a detailed description of the protocol, please see the [whitepaper](https://docs.orbiter.finance/whitepaper_en)._

### Overview

### Contracts

**[L2_OrbiterMaker.sol](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/contracts/L2_OrbiterMaker.sol)** - Responsible for Arbitrum coin dealer registration, voucher processing, and clearing related logic

**[L1_PushManServer.sol](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/contracts/L1_PushManServer.sol)** - Obtain the transaction information of Rollup on the L1 network, and provide the functions of generating loan vouchers and initiating arbitration

**[iExtractor.sol](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/contracts/interface/iExtractor.sol)** - Responsible for the interface declaration contract that interacts with different Rollups

#### Bridges

### Definitions
