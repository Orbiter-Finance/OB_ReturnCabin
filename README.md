The contract has not been developed yet.

todoList

- Add more necessary screws
- Clean code, Complete README
- Development of SPV module
- Tested in rinkeby

---

Orbiter's world consists of two events, the user initiates the event in the initiating network, and the maker responds to the event in the target network. This model is an abstraction of many real needs, such as: cross-chain swap of the same token, cross-chain swap of different tokens, and cross-chain swap of NFT. In order to allow users to initiate events with confidence, the maker pledges sufficient margin in the on-chain contract to make a promise to respond to the event: if the maker fails to respond to the initiation event in the promised way, the promise contract will compensate the user. The compensation must meet the following conditions. The user needs to prove that the initiating event has occurred, and the maker cannot prove that the corresponding response event has occurred.

**OrbiterMakerDeposit.sol (MDC contract):**

MDC is a storage contract for margin, and the general arbitration process logic is stipulated in the contract. In order to ensure that the user can get compensation in the event of a bad situation, the maker will deposit the margin in the MDC contract in advance, and at the same time lock a sufficient margin, so as to make a certain cross-Rollup transfer (binding contract, environment and currency) at MDC promise.

**IOrbiterExtrator.sol (SPV_extrater contract):**

Short for Simplified Payment Verification, SPV is a lightweight client to verify blockchain transactions, downloading only block headers and requesting proof of inclusion to the blockchain in the Merkle Tree.

The security model includes: 1. The SPV certification process can be trusted. 2. Trust in the state root provided. In rollup, L1 will store the state root data of L2, and the trust of the state root is guaranteed by the consensus mechanism of L1, which means that as long as the SPV certification process can be trusted, the proof of the occurrence of L2 events is credible . If there is a side chain in the event chain, then it is necessary to ensure that there is a mechanism to transmit the root hash of the side chain to the network where the MDC is located. An off-chain approach is supported. Although the security assumption of the side chain is lower than rollup, it will not affect other chains because of one side chain.

**IOrbiterProtocal.sol (event binding contract):**

The event binding contract stipulates that when the initiating event is A, the response event is equal to P(A), and there is a corresponding relationship between A and P(A). In the normal process, when the sender submits A that conforms to the specification, the maker will calculate P(A) under the chain according to the event binding contract, and send P(A) to the response environment. If the maker generates F(A) with a specification that does not conform to the binding contract, for example, the transaction amount is only half of A, and uses this as a response to the event. In the appeal process, even if the maker can prove that he responded to the event with P(A) A, but it cannot make F(A)=P(A), so it also fails.
