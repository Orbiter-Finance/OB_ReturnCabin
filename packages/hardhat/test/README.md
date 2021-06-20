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
| singleLoanLiquidation | code | public | pushManServer |
| AccountLiquidation | code/ready | internal | ------ |

L1_PushManServer test
| name | state | region | Caller |
| ------ | ------ | ------ | ------ |
| ------ | design/code/ready | public/internal | user/coinDealer/owner/pushMan |
| initiExtractorAddress | code | public | owner |
| getL1TransferInfo | code | internal | ------ |
| convertToLoanProof | code | internal | ------ |
| sendMessageToL2Orbiter | code | public | user |
| generateProofID | code | internal | ------ |

### tests

**[L1_PushManServer.test.js](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/test/L1_PushManServer.test.js)** - Test file of L1_PushManServer.sol

**[L2_OrbiterMaker.test.js](https://github.com/OrbiterCross/V2-contracts/blob/develop/packages/hardhat/test/L2_OrbiterMaker.test.js)** - Test file of L2_OrbiterMaker.sol
