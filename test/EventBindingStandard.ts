import { ethers } from "hardhat";
import { Signer } from "ethers";
import { expect } from "chai";
import { EventBindingStandard } from "../build/types";

describe("EventBindingStandard contract", function () {
    let accounts: Signer[];
    let eventBinding: EventBindingStandard;

    beforeEach(async function () {
        accounts = await ethers.getSigners();

        const EventBindingStandard = await ethers.getContractFactory("EventBindingStandard");
        eventBinding = await EventBindingStandard.deploy();

        await eventBinding.deployed();
    });
    it("should getSrouceValue3Args", async function () {
        const result = await eventBinding.getSrouceValue3Args("16283000000001213", 18);
        expect(result.dealerId).eq('1');
        expect(result.chainId).eq('21');
        expect(result.ebcId).eq('3');
    });
    
    it("should get response amount", async function () {
      
    });
    // it("should response hash", async function () {
    //     // send to mrc
    //     eventBinding.getResponseResult({
    //         from: "",
    //         to: "",
    //         tokenAddress: "",
    //         txHash: "",
    //         blockHash: "",
    //         blockNumber: "",
    //         chainId: "",
    //         nonce: "",
    //         gas: "",
    //         gasPrice: "",
    //         value: "",
    //         transactionIndex: "",
    //         timeStamp: "",
    //         data: ""
    //     });
    // });

  
});
