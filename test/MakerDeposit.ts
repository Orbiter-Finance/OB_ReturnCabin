import { ethers } from "hardhat";
import { Signer } from "ethers";
import { expect } from "chai";
import { EventBindingStandard, MakerDeposit, MakerFactory, Manager } from "../build/types";
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { deployMakerFactoryFixture } from "./MakerFactory";

export async function deployMakerDepositFixture() {
    const { manager, makerFactory } = await deployMakerFactoryFixture();
    const [_, signer2] = await ethers.getSigners();
    await makerFactory.connect(signer2).createMaker();
    // 
    const mdcAddr = await makerFactory.makerByOwner(signer2.address);
    const makerDeposit = await ethers.getContractAt('MakerDeposit', mdcAddr)
    // bind event
    return {
        makerDeposit,
        makerFactory,
        manager,
    }
}
describe("MakerDeposit", function () {
    let accounts: Signer[];
    let eventBinding: EventBindingStandard;
    let makerDeposit!: MakerDeposit;
    let makerFactory!: MakerFactory;
    let manager!: Manager;
    beforeEach(async function () {
        if (!manager) {
            const fixture = await loadFixture(deployMakerDepositFixture);
            makerDeposit = fixture.makerDeposit;
            makerFactory = fixture.makerFactory;
            manager = fixture.manager;
            accounts = await ethers.getSigners();
        }
    });

    it('should Already initialized', async () => {
        const makerAddr = await makerFactory.makerByOwner(accounts[1].getAddress());
        await expect(makerAddr).not.empty
        const makerDeposit = await ethers.getContractAt("MakerDeposit", makerAddr);
        await expect(makerDeposit.initialize()).to.be.revertedWith('Already initialized');
    });
    it('One pledge, two activations', async () => {
        this.timeout(1000 * 60);
        const { manager, makerDeposit } = await loadFixture(deployMakerDepositFixture);
        async function createPair1() {
            const config = {
                tradingFee: 0.1 * 10000,
                withholdingFee: 0.001 * 10000,
                maxPrice: ethers.BigNumber.from('500000000000000000'),
                minPrice: ethers.BigNumber.from('100000000000000000'),
                state: 1
            }
            const tx = await makerDeposit.connect(accounts[1]).start({
                s: 1,
                d: 2,
                sToken: "0x0000000000000000000000000000000000000000",
                dToken: "0x0000000000000000000000000000000000000000",
            }, config.tradingFee, config.withholdingFee, config.minPrice, config.maxPrice, {
                value: ethers.BigNumber.from('60000000000000000000')
            })
            const { events } = await tx.wait();
            expect(events).not.empty;
            expect(events![0].event).to.equal("Start");
            const pairKey = ethers.utils.solidityKeccak256(['uint8', 'uint8', 'uint', 'uint'], [1, 2, '0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000']);
            expect(events![0].args![0]).to.equal(pairKey);
            // 
            const pair = await makerDeposit.pairs(pairKey);
            expect(pair.tradingFee).eq(config.tradingFee);

            // check idle
            const sourceToken = await manager.getTokenInfo(1, '0x0000000000000000000000000000000000000000');
            const pairPledgeByChainTokenAmount = (await makerDeposit.getPairPledgeByChainToken(1, sourceToken.layer1Token));
            expect(pairPledgeByChainTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const pairPledgeByTokenAmount = await makerDeposit.getPairPledgeByToken('0x0000000000000000000000000000000000000000');
            expect(pairPledgeByTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const idleAmount = await makerDeposit.getIdleAmount(sourceToken.layer1Token);
            expect(idleAmount).eq('10000000000000000000');
        }
        await createPair1();

        async function createPair2() {
            const config = {
                tradingFee: 0.1 * 10000,
                withholdingFee: 0.001 * 10000,
                maxPrice: ethers.BigNumber.from('600000000000000000'),
                minPrice: ethers.BigNumber.from('100000000000000000'),
                state: 1
            }
            const tx = await makerDeposit.connect(accounts[1]).start({
                s: 1,
                d: 7,
                sToken: "0x0000000000000000000000000000000000000000",
                dToken: "0x0000000000000000000000000000000000000000",
            }, config.tradingFee, config.withholdingFee, config.minPrice, config.maxPrice)
            const { events } = await tx.wait();
            expect(events).not.empty;
            expect(events![0].event).to.equal("Start");
            const pairKey = ethers.utils.solidityKeccak256(['uint8', 'uint8', 'uint', 'uint'], [1, 7, '0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000']);
            expect(events![0].args![0]).to.equal(pairKey);
            // 
            const pair = await makerDeposit.pairs(pairKey);
            expect(pair.tradingFee).eq(config.tradingFee);

            // check idle
            const sourceToken = await manager.getTokenInfo(1, '0x0000000000000000000000000000000000000000');
            const pairPledgeByChainTokenAmount = (await makerDeposit.getPairPledgeByChainToken(1, sourceToken.layer1Token));
            expect(pairPledgeByChainTokenAmount).eq(ethers.BigNumber.from('60000000000000000000'));
            const pairPledgeByTokenAmount = await makerDeposit.getPairPledgeByToken('0x0000000000000000000000000000000000000000');
            expect(pairPledgeByTokenAmount).eq(ethers.BigNumber.from('60000000000000000000'));
            const idleAmount = await makerDeposit.getIdleAmount(sourceToken.layer1Token);
            expect(idleAmount).eq(0);
        }
        await createPair2();
    });

    it('Insufficient collateral for the second time', async () => {
        this.timeout(1000 * 60);
        const { manager, makerDeposit } = await loadFixture(deployMakerDepositFixture);
        async function createPair1() {
            const config = {
                tradingFee: 0.1 * 10000,
                withholdingFee: 0.001 * 10000,
                maxPrice: ethers.BigNumber.from('500000000000000000'),
                minPrice: ethers.BigNumber.from('100000000000000000'),
                state: 1
            }
            const tx = await makerDeposit.connect(accounts[1]).start({
                s: 1,
                d: 2,
                sToken: "0x0000000000000000000000000000000000000000",
                dToken: "0x0000000000000000000000000000000000000000",
            }, config.tradingFee, config.withholdingFee, config.minPrice, config.maxPrice, {
                value: ethers.BigNumber.from('50000000000000000000')
            })
            const { events } = await tx.wait();
            expect(events).not.empty;
            expect(events![0].event).to.equal("Start");
            const pairKey = ethers.utils.solidityKeccak256(['uint8', 'uint8', 'uint', 'uint'], [1, 2, '0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000']);
            expect(events![0].args![0]).to.equal(pairKey);
            // 
            const pair = await makerDeposit.pairs(pairKey);
            expect(pair.tradingFee).eq(config.tradingFee);

            // check idle
            const sourceToken = await manager.getTokenInfo(1, '0x0000000000000000000000000000000000000000');
            const pairPledgeByChainTokenAmount = (await makerDeposit.getPairPledgeByChainToken(1, sourceToken.layer1Token));
            expect(pairPledgeByChainTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const pairPledgeByTokenAmount = await makerDeposit.getPairPledgeByToken('0x0000000000000000000000000000000000000000');
            expect(pairPledgeByTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const idleAmount = await makerDeposit.getIdleAmount(sourceToken.layer1Token);
            expect(idleAmount).eq(0);
        }
        await createPair1();

        async function createPair2() {
            const config = {
                tradingFee: 0.1 * 10000,
                withholdingFee: 0.001 * 10000,
                maxPrice: ethers.BigNumber.from('600000000000000000'),
                minPrice: ethers.BigNumber.from('100000000000000000'),
                state: 1
            }
            const tx = makerDeposit.connect(accounts[1]).start({
                s: 1,
                d: 7,
                sToken: "0x0000000000000000000000000000000000000000",
                dToken: "0x0000000000000000000000000000000000000000",
            }, config.tradingFee, config.withholdingFee, config.minPrice, config.maxPrice)
            await expect(tx).to.be.revertedWith('Insufficient idle funds for pledge');
        }
        await createPair2();
    });

    it('Insufficient collateral for the second time, increase the collateral deposit', async () => {
        this.timeout(1000 * 60);
        const { manager, makerDeposit } = await loadFixture(deployMakerDepositFixture);
        async function createPair1() {
            const config = {
                tradingFee: 0.1 * 10000,
                withholdingFee: 0.001 * 10000,
                maxPrice: ethers.BigNumber.from('500000000000000000'),
                minPrice: ethers.BigNumber.from('100000000000000000'),
                state: 1
            }
            const tx = await makerDeposit.connect(accounts[1]).start({
                s: 1,
                d: 2,
                sToken: "0x0000000000000000000000000000000000000000",
                dToken: "0x0000000000000000000000000000000000000000",
            }, config.tradingFee, config.withholdingFee, config.minPrice, config.maxPrice, {
                value: ethers.BigNumber.from('50000000000000000000')
            })
            const { events } = await tx.wait();
            expect(events).not.empty;
            expect(events![0].event).to.equal("Start");
            const pairKey = ethers.utils.solidityKeccak256(['uint8', 'uint8', 'uint', 'uint'], [1, 2, '0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000']);
            expect(events![0].args![0]).to.equal(pairKey);
            // 
            const pair = await makerDeposit.pairs(pairKey);
            expect(pair.tradingFee).eq(config.tradingFee);

            // check idle
            const sourceToken = await manager.getTokenInfo(1, '0x0000000000000000000000000000000000000000');
            const pairPledgeByChainTokenAmount = (await makerDeposit.getPairPledgeByChainToken(1, sourceToken.layer1Token));
            expect(pairPledgeByChainTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const pairPledgeByTokenAmount = await makerDeposit.getPairPledgeByToken('0x0000000000000000000000000000000000000000');
            expect(pairPledgeByTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const idleAmount = await makerDeposit.getIdleAmount(sourceToken.layer1Token);
            expect(idleAmount).eq(0);
        }
        await createPair1();

        async function createPair2() {
            const config = {
                tradingFee: 0.1 * 10000,
                withholdingFee: 0.001 * 10000,
                maxPrice: ethers.BigNumber.from('600000000000000000'),
                minPrice: ethers.BigNumber.from('100000000000000000'),
                state: 1
            }
            const tx = await makerDeposit.connect(accounts[1]).start({
                s: 1,
                d: 7,
                sToken: "0x0000000000000000000000000000000000000000",
                dToken: "0x0000000000000000000000000000000000000000",
            }, config.tradingFee, config.withholdingFee, config.minPrice, config.maxPrice, {
                value: ethers.BigNumber.from('10000000000000000000')
            })
            const { events } = await tx.wait();
            expect(events).not.empty;
            expect(events![0].event).to.equal("Start");
            const pairKey = ethers.utils.solidityKeccak256(['uint8', 'uint8', 'uint', 'uint'], [1, 7, '0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000']);
            expect(events![0].args![0]).to.equal(pairKey);
            // 
            const pair = await makerDeposit.pairs(pairKey);
            expect(pair.tradingFee).eq(config.tradingFee);

            // check idle
            const sourceToken = await manager.getTokenInfo(1, '0x0000000000000000000000000000000000000000');
            const pairPledgeByChainTokenAmount = (await makerDeposit.getPairPledgeByChainToken(1, sourceToken.layer1Token));
            expect(pairPledgeByChainTokenAmount).eq(ethers.BigNumber.from('60000000000000000000'));
            // 
            const pairPledgeByTokenAmount = await makerDeposit.getPairPledgeByToken('0x0000000000000000000000000000000000000000');
            expect(pairPledgeByTokenAmount).eq(ethers.BigNumber.from('60000000000000000000'));

            const idleAmount = await makerDeposit.getIdleAmount(sourceToken.layer1Token);
            expect(idleAmount).eq(0);
        }
        await createPair2();
    });

    it('Release the remaining', async () => {
        this.timeout(1000 * 60);
        const { manager, makerDeposit } = await loadFixture(deployMakerDepositFixture);
        async function createPair1() {
            const config = {
                tradingFee: 0.1 * 10000,
                withholdingFee: 0.001 * 10000,
                maxPrice: ethers.BigNumber.from('500000000000000000'),
                minPrice: ethers.BigNumber.from('100000000000000000'),
                state: 1
            }
            const tx = await makerDeposit.connect(accounts[1]).start({
                s: 1,
                d: 2,
                sToken: "0x0000000000000000000000000000000000000000",
                dToken: "0x0000000000000000000000000000000000000000",
            }, config.tradingFee, config.withholdingFee, config.minPrice, config.maxPrice, {
                value: ethers.BigNumber.from('50000000000000000000')
            })
            const { events } = await tx.wait();
            expect(events).not.empty;
            expect(events![0].event).to.equal("Start");
            const pairKey = ethers.utils.solidityKeccak256(['uint8', 'uint8', 'uint', 'uint'], [1, 2, '0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000']);
            expect(events![0].args![0]).to.equal(pairKey);
            // 
            const pair = await makerDeposit.pairs(pairKey);
            expect(pair.tradingFee).eq(config.tradingFee);

            // check idle
            const sourceToken = await manager.getTokenInfo(1, '0x0000000000000000000000000000000000000000');
            const pairPledgeByChainTokenAmount = (await makerDeposit.getPairPledgeByChainToken(1, sourceToken.layer1Token));
            expect(pairPledgeByChainTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const pairPledgeByTokenAmount = await makerDeposit.getPairPledgeByToken('0x0000000000000000000000000000000000000000');
            expect(pairPledgeByTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const idleAmount = await makerDeposit.getIdleAmount(sourceToken.layer1Token);
            expect(idleAmount).eq(0);
        }
        await createPair1();

        async function createPair2() {
            const config = {
                tradingFee: 0.1 * 10000,
                withholdingFee: 0.001 * 10000,
                maxPrice: ethers.BigNumber.from('400000000000000000'),
                minPrice: ethers.BigNumber.from('100000000000000000'),
                state: 1
            }
            const tx = await makerDeposit.connect(accounts[1]).start({
                s: 1,
                d: 7,
                sToken: "0x0000000000000000000000000000000000000000",
                dToken: "0x0000000000000000000000000000000000000000",
            }, config.tradingFee, config.withholdingFee, config.minPrice, config.maxPrice)
            const { events } = await tx.wait();
            expect(events).not.empty;
            expect(events![0].event).to.equal("Start");
            const pairKey = ethers.utils.solidityKeccak256(['uint8', 'uint8', 'uint', 'uint'], [1, 7, '0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000']);
            expect(events![0].args![0]).to.equal(pairKey);
            // 
            const pair = await makerDeposit.pairs(pairKey);
            expect(pair.tradingFee).eq(config.tradingFee);

            // check idle
            const sourceToken = await manager.getTokenInfo(1, '0x0000000000000000000000000000000000000000');
            const pairPledgeByChainTokenAmount = (await makerDeposit.getPairPledgeByChainToken(1, sourceToken.layer1Token));
            expect(pairPledgeByChainTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            // 
            const pairPledgeByTokenAmount = await makerDeposit.getPairPledgeByToken('0x0000000000000000000000000000000000000000');
            expect(pairPledgeByTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const idleAmount = await makerDeposit.getIdleAmount(sourceToken.layer1Token);
            expect(idleAmount).eq(0);
        }
        await createPair2();

        async function createPair3() {
            const config = {
                tradingFee: 0.1 * 10000,
                withholdingFee: 0.001 * 10000,
                maxPrice: ethers.BigNumber.from('500000000000000000'),
                minPrice: ethers.BigNumber.from('100000000000000000'),
                state: 1
            }
            const tx = await makerDeposit.connect(accounts[1]).start({
                s: 1,
                d: 2,
                sToken: "0x0000000000000000000000000000000000000000",
                dToken: "0x0000000000000000000000000000000000000000",
            }, config.tradingFee, config.withholdingFee, config.minPrice, config.maxPrice, {
                value: ethers.BigNumber.from('50000000000000000000')
            })
            const { events } = await tx.wait();
            expect(events).not.empty;
            expect(events![0].event).to.equal("Start");
            const pairKey = ethers.utils.solidityKeccak256(['uint8', 'uint8', 'uint', 'uint'], [1, 2, '0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000']);
            expect(events![0].args![0]).to.equal(pairKey);
            // 
            const pair = await makerDeposit.pairs(pairKey);
            expect(pair.tradingFee).eq(config.tradingFee);

            // check idle
            const sourceToken = await manager.getTokenInfo(1, '0x0000000000000000000000000000000000000000');
            const pairPledgeByChainTokenAmount = (await makerDeposit.getPairPledgeByChainToken(1, sourceToken.layer1Token));
            expect(pairPledgeByChainTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const pairPledgeByTokenAmount = await makerDeposit.getPairPledgeByToken('0x0000000000000000000000000000000000000000');
            expect(pairPledgeByTokenAmount).eq(ethers.BigNumber.from('50000000000000000000'));
            const idleAmount = await makerDeposit.getIdleAmount(sourceToken.layer1Token);
            expect(idleAmount).eq(0);
        }
        // await createPair3();
        // TODO;
    });


});
