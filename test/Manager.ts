import { ethers } from "hardhat";
import { Signer } from "ethers";
import { expect } from "chai";
import { Manager } from "../typechain-types";

describe("Manager contract", function () {
    let accounts: Signer[];
    let manager: Manager;

    beforeEach(async function () {
        accounts = await ethers.getSigners();

        const Manager = await ethers.getContractFactory("Manager");
        manager = await Manager.deploy();

        await manager.deployed();
    });

    it("should register SPV", async function () {
        const [owner, spv] = accounts;
        const chainId = 1;
        await manager.connect(owner).registerSPV(chainId, spv.getAddress());

        expect(await manager.spvs(chainId)).to.equal(await spv.getAddress());
    });

    it("should register chain", async function () {
        const [owner, spv] = accounts;

        const chainId = 1;
        const batchLimit = 100;
        const tokenInfos = [
            {
                precision: 18,
                tokenAddress: ethers.constants.AddressZero,
                mainAddress: ethers.constants.AddressZero,
            },
        ];
        await manager.connect(owner).registerSPV(chainId, spv.getAddress());
        await manager
            .connect(owner)
            .registerChain(chainId, batchLimit, tokenInfos);

        const chain = await manager.chains(chainId);
        expect(chain.id).to.equal(chainId);
        expect(chain.batchLimit).to.equal(batchLimit);
        const token = await manager.getTokenInfo(chainId, ethers.constants.AddressZero);
        expect(token.precision).to.equal(
            18
        );
    });

    it("should register token", async function () {
        const [owner, spv] = accounts;

        const chainId = 1;
        const tokenPrecision = 18;
        const tokenAddress = ethers.constants.AddressZero;
        const mainAddress = ethers.constants.AddressZero;
        await manager.connect(owner).registerSPV(chainId, spv.getAddress());
        await manager.connect(owner).registerChain(chainId, 100, []);
        await manager
            .connect(owner)
            .registerToken(chainId, tokenPrecision, tokenAddress, mainAddress);

        const token = await manager.getTokenInfo(chainId, tokenAddress);
        expect(token.precision).to.equal(tokenPrecision);
        expect(token.tokenAddress).to.equal(tokenAddress);
        expect(token.mainAddress).to.equal(mainAddress);
    });
});
