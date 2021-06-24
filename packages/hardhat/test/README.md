# `test`

1. Related test documents for orbiter contract.

## Protocol Design

_For a detailed description of the protocol, please see the [whitepaper](https://docs.orbiter.finance/whitepaper_en)._

### Overview

L2_OrbiterMaker Test
| name | state | region | Caller |
| ------ | ------ | ------ | ------ |
| ------ | design/code/ready | public/internal | user/coinDealer/owner/pushMan |
| registerCoinDealer | ready | public | coinDealer |
| stopCoinDealer | ready | public | coinDealer |
| withDrawCoinDealer | ready | public | coinDealer |
| RepaymentTokenByCoinDealer | ready | public | coinDealer |
| singleLoanLiquidation | ready | public | pushManServer |
| AccountLiquidation | ready | internal | ------ |

L1_PushManServer test
| name | state | region | Caller |
| ------ | ------ | ------ | ------ |
| ------ | design/code/ready | public/internal | user/coinDealer/owner/pushMan |
| initiExtractorAddress | code | public | owner |
| sendMessageToL2Orbiter | code | public | user |
| generateProofID | code | internal | ------ |

Extractor_zk test
| name | state | region | Caller |
| ------ | ------ | ------ | ------ |
| ------ | design/code/ready | public/internal | user/coinDealer/owner/pushMan |
| getTransactionLoanProof | ready | public | user |
| appeal | ready | public | user |

Extractor_l1 test
| name | state | region | Caller |
| ------ | ------ | ------ | ------ |
| ------ | design/code/ready | public/internal | user/coinDealer/owner/pushMan |
| setTransactionInfoInL1 | ready | public | pushMan |
| getTransactionLoanProof | ready | public | user |
| appeal | ready | public | user |

### tests

**[L1_PushManServer.test.js](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/test/L1_PushManServer.test.js)** - Test file of L1_PushManServer.sol

**[L2_OrbiterMaker.test.js](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/test/L2_OrbiterMaker.test.js)** - Test file of L2_OrbiterMaker.sol

**[Extractor_l1.test.js](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/test/Extractor_l1.test.js)** - Test file of L2_OrbiterMaker.sol

**[Extractor_zk.test.js](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/test/Extractor_zk.test.js)** - Test file of L2_OrbiterMaker.sol
