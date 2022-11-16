## Contract System Design


For the scheme to become infrastructure, it is essential to abstract a general business model from actual requirements, including cross-chain transfer requirements of the same token,  different tokens, and NFT.

Orbiter's world comprises two parts: Sender initiating events in the initiating network and Maker responding events in the target network. 

Orbiter's mission is to ensure that these two events happen in unison. 

How does Orbiter complete the process? 

A. To make Senders feel safe to initiate events, Makers pledges sufficient margin in the MDC contract on-chain to respond to the event. 

B. If Maker fails to respond to the Sender's initiated event promised, Sender should send an arbitration request to MDC contract and provide proof of initiating event. 

C. If Maker fails to provide MDC contract with proof of responding event within the specified time, MDC contract will compensate Sender with Maker's margin.

![orbiter_ mechanism](https://raw.githubusercontent.com/houhou139/Orbiter/main/orbiter_%20mechanism.jpg)



Orbiter’s system contains three contracts and modules:

* **MDC（Maker Deposit Contract）**

  MDC has two core functions: keeping Maker’s margin, dispute resolution, and handling return assets and compensation. 

* **EBC (Event Binding Contracts)** 

  EBC is used to calculate the corresponding valid Target Tx based on the Source Tx.

* **SPV Light Client.** 

  SPV proves that Source Tx has occurred in the Source Network.

These three contracts and modules run on Chain X, which can be any smart contract supporting environment in the Ethereum system, the Ethereum mainnet, any Rollups, or even Source Network or Target Network as long as the chain keeps smart contracts. 

The three contract modules work together like this:

* Maker can support Sender's cross-rollup transfer requirements after depositing a margin in the MDC contract.

* In the normal correct transfer process, after a Source Tx is generated in the Source network, the EBC calculates the Target Tx that meets the requirements according to the Source Tx. Maker sends Target Tx to Target Network to complete a cross-rollup transfer.

* But when Maker does not send Target Tx in time, Sender should provide proof of Source Tx to SPV on Chain X and applies for arbitration to the MDC contract. The MDC obtains the Source Tx occurrence proof through SPV, gets the Source Tx validity proof through EBC, sets the arbitration request as an unprocessed event, and waits for Maker to submit the Target Tx proof. Suppose Maker fails to provide Target Tx proof promptly. In that case, MDC will initiate the compensation process, return assets and send compensation to Sender on Chain X with Maker's margin.



## MDC

**What is the MDC?**

MDC(Maker Deposit Contract) is a storage contract for margin, which specifies a common arbitration process logic. Maker will pre-deposit the margin into the MDC contract and lock a sufficient margin to make a specific cross-rollup transfer (Event binding contract, environment, and currency) to ensure that the Sender can be compensated in an adverse case.

**How does the MDC deal with the  arbitration？**

Arbitration proceedings will be initiated when all of the following conditions happen.

* Source Tx occurred, but the responding event did not happen.
* Maker does not complete the transfer during the arbitration wait time. (Arbitration wait time is the larger value of Source Network withdrawal time and Target Network withdrawal time).
* Sender or anyone else has filed an arbitration request.
* Maker was unable to submit proof of occurrence for Target Tx in time.

After the whole arbitration process has been completed, the Sender will get assets back and compensation.

Orbiter reads the valid hash value recorded by two networks in the mainnet as a basis for arbitration.

**The following conditions should make Sender's decision:**

* MDC margin condition 
* Maker's historical behavior

Before Sender decides to transfer, it only needs to know the operation condition of Maker's address corresponding to other transfers off-chain to see the Maker's ability and choose whether to transfer.

## SPV

We are developing an SPV module, and it will be open-sourced when we complete it. Currently, the state is:

- [x] The SPV of L1, which support EIP-1559, has been completed.
- [ ] The SPV of zkSync is being developed. About the proof process of zkSync,, [See this article for design](zksync_spv.md)
- [ ] We have researched the SPV of Arbitrum.
- [ ] And we just started research about the SPV of StarkNet.
- [x] The SPV of Polygon and the SPV of L1 are in the same logic.

They will be deployed in about two month.

## Milestone

![](https://user-images.githubusercontent.com/81635969/151336307-609eb79c-5740-4d8e-8cdf-e4ef253cc9fb.jpg)



