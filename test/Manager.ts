import { ethers } from "hardhat";
import { Signer } from "ethers";
import { expect } from "chai";
import { Manager } from "../build/types";
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
export async function deployManagerFixture() {
    const Manager = await ethers.getContractFactory("Manager");
    const manager = await Manager.deploy();

    await manager.deployed();
    // init chain
    const chainsList = [
        {
            id: 1,
            batchLimit: 100,
            tokens: [
                {
                    symbol: "ETH",
                    tokenAddress: "0x0000000000000000000000000000000000000000",
                    decimals: 18,
                    layer1Token: "0x0000000000000000000000000000000000000000"
                },
                {
                    symbol: "USDT",
                    tokenAddress: "0xdac17f958d2ee523a2206206994597c13d831ec7",
                    decimals: 18,
                    layer1Token: "0xdac17f958d2ee523a2206206994597c13d831ec7"
                }
            ]
        },
        {
            id: 2,
            batchLimit: 100,
            tokens: [
                {
                    symbol: "ETH",
                    tokenAddress: "0x0000000000000000000000000000000000000000",
                    decimals: 18,
                    layer1Token: "0x0000000000000000000000000000000000000000"
                },
                {
                    symbol: "USDT",
                    tokenAddress: "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9",
                    decimals: 18,
                    layer1Token: "0xdac17f958d2ee523a2206206994597c13d831ec7"
                }
            ]
        },
        {
            id: 7,
            batchLimit: 100,
            tokens: [
                {
                    symbol: "ETH",
                    tokenAddress: "0x0000000000000000000000000000000000000000",
                    decimals: 18,
                    layer1Token: "0x0000000000000000000000000000000000000000"
                },
                {
                    symbol: "USDT",
                    tokenAddress: "0x94b008aa00579c1307b0ef2c499ad98a8ce58e58",
                    decimals: 18,
                    layer1Token: "0xdac17f958d2ee523a2206206994597c13d831ec7"
                }
            ]
        }
    ]
    for (const chain of chainsList) {
        await manager.registerChain(chain.id, chain.batchLimit, chain.tokens);
        const data = await manager.chains(chain.id);
        expect(chain.batchLimit).to.equal(data.batchLimit);
    }
    // init spv
    const chainId = 1;
    await manager.registerSPV(chainId, '0x0000000000000000000000000000000000000009');

    return { manager };
}

describe("Manager contract", function () {
    let accounts: Signer[];
    let manager: Manager;
    beforeEach(async function () {
        accounts = await ethers.getSigners();
        const fixture = await loadFixture(deployManagerFixture);
        manager = fixture.manager;
    });

    it("should register SPV", async function () {
        const chainId = 1;
        await manager.registerSPV(chainId, '0x0000000000000000000000000000000000000001');
        expect(await manager.spvs(chainId)).to.equal(await '0x0000000000000000000000000000000000000001');
    });
    it("should register chain", async function () {
        const [owner, spv] = accounts;

        const chainId = 1;
        const batchLimit = 100;
        const tokenInfos = [
            {
                decimals: 18,
                tokenAddress: ethers.constants.AddressZero,
                layer1Token: ethers.constants.AddressZero,
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
        expect(token.decimals).to.equal(
            18
        );
    });

    it("should register token", async function () {
        const [owner, spv] = accounts;

        const chainId = 1;
        const tokenPrecision = 18;
        const tokenAddress = ethers.constants.AddressZero;
        const layer1Token = ethers.constants.AddressZero;
        await manager.connect(owner).registerSPV(chainId, spv.getAddress());
        await manager.connect(owner).registerChain(chainId, 100, []);
        await manager
            .connect(owner)
            .registerToken(chainId, tokenPrecision, tokenAddress, layer1Token);

        const token = await manager.getTokenInfo(chainId, tokenAddress);

        expect(token.decimals).to.equal(tokenPrecision);
        expect(token.tokenAddress).to.equal(tokenAddress);
        expect(token.layer1Token).to.equal(layer1Token);
    });
    it("should register ERC20 Token", async function () {
        const [owner, spv] = accounts;

        const chainId = 2;
        const tokenPrecision = 6;
        const tokenAddress = "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9";
        const layer1Token = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        await manager.connect(owner).registerSPV(chainId, spv.getAddress());
        await manager.connect(owner).registerChain(chainId, 100, []);
        await manager
            .connect(owner)
            .registerToken(chainId, tokenPrecision, tokenAddress, layer1Token);

        const token = await manager.getTokenInfo(chainId, tokenAddress);
        expect(token.decimals).to.equal(tokenPrecision);
        expect(token.tokenAddress).to.equal(tokenAddress);
        expect(token.layer1Token).to.equal(layer1Token);
    });

    it("should register Starknet DAI Token", async function () {
        const [owner, spv] = accounts;
        const chainId = 4;
        const tokenPrecision = 18;
        const tokenAddress = "0x00da114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3";
        const layer1Token = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
        await manager.connect(owner).registerSPV(chainId, spv.getAddress());
        await manager.connect(owner).registerChain(chainId, 100, []);
        await manager
            .connect(owner)
            .registerToken(chainId, tokenPrecision, tokenAddress, layer1Token);
        const token = await manager.getTokenInfo(chainId, tokenAddress);
        expect(token.decimals).to.equal(tokenPrecision);
        expect(token.tokenAddress).to.equal(tokenAddress);
        expect(token.layer1Token).to.equal(layer1Token);
    });
});
