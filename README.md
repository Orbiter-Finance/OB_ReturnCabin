The contract has not yet been developed.

 to-do list.

- Add more necessary screws
- Clean code,  unified naming rules, clear README
- Develop SPV module
- Tested in rinkeby

---

Orbiter's world comprises Sender initiating events in the initiating network and Maker responding events in the target network. This model abstracts many complex things, such as cross-chain swap of the same tokens, different tokens, and NFT. To make Senders feel safe to initiate events, Makers pledges sufficient margin in the on-chain contract to respond to the event, and it's like making a promise: If Makers fails to respond to the Sender's initiated event as promised, the promise contract will compensate the Sender. The compensation must meet the following conditions. The Sender needs to prove that the initiating event has occurred, and the Maker cannot prove that a corresponding responding event has occurred.

**OrbiterMakerDeposit.sol (MDC contract):**
MDC is a storage contract for margin, which specifies a common arbitration process logic. Maker will pre-deposit the margin into the MDC contract and lock a sufficient margin to make a specific cross-rollup transfer (binding-event contract, environment, and currency) to ensure that the Sender can be compensated in an adverse case.

**IOrbiterExtrator.sol (SPV_extrater contract):**
Short for **Simplified Payment Verification**, SPV is a lightweight client to verify blockchain transactions, downloading only block headers and requesting proof of inclusion to the blockchain in the Merkle Tree.
The security model includes two parts: 1. Be trusted proof process of SPV. 2. Trust in the state root provided. 
In rollup, Layer 1 will store the state root data of Layer 2. L1's consensus mechanism ensures that the state root is trusted. It means if the proof process of SPV is trusted, the proof of the occurrence of the L2 event is also credible. Although the security of the sidechains may be lower than rollups, one sidechain does not affect the others. If there are sidechains in the chain of events, then there needs to be a trusted mechanism to pass the hash of the sidechain root to the MDC network, such as Rainbow, XDAI, BNB, and Matic, all of which can be supported by some off-chain way in the future.

**IOrbiterProtocal.sol (binding-event contract):**
The binding-event contract  stipulates that when the initiating event is A, the responding event is  P(A), and a corresponding relationship between A and P(A).
In the normal process, when the Sender submits the A that meets the specification, the Maker will calculate P(A) off-chain according to the binding-event contract  and send P(A) to the responding environment. Suppose Maker generates F(A) with a specification that does not comply with the binding-event contract . In that case, the transaction amount is only half that of A and uses it as A responding event, even if Maker can prove that it responded to event A with P(A), it cannot make F(A)=P(A) and therefore fails in the appeal process.
