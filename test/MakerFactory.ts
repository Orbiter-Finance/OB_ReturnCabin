import { ethers } from 'hardhat';
import { expect } from 'chai';
import { MakerFactory, Manager } from '../build/types';
import { deployManagerFixture } from './Manager';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
export async function deployMakerFactoryFixture() {
    const { manager } = await deployManagerFixture();
    const [signer1, signer2, signer3] = await ethers.getSigners();
    let MakerDeposit = await ethers.getContractFactory('MakerDeposit');
    const makerDeposit = await MakerDeposit.deploy()
    await makerDeposit.deployed();
    const MakerFactory = await ethers.getContractFactory('MakerFactory', signer1);
    // manager
    const makerFactory = await MakerFactory.deploy(manager.address, 100, makerDeposit.address);
    await makerFactory.deployed();
    return {
        manager,
        makerFactory,
        makerDeposit
    }
}

describe('MakerFactory', async () => {
    let makerFactory!: MakerFactory;
    let manager:Manager;
    let user1: any;
    beforeEach(async () => {
        const fixture = await loadFixture(deployMakerFactoryFixture);
        makerFactory = fixture.makerFactory;
        manager = fixture.manager;
        const [signer1, signer2, signer3] = await ethers.getSigners();
        user1 = signer2;
    });

    it('should allow owner to set manager', async () => {
        const newManager = user1.address;
        await makerFactory.setManager(newManager);
        expect(await makerFactory.manager()).to.equal(newManager);
    });

    it('should not allow non-owner to set manager', async () => {
        const newManager = user1.address;
        await expect(makerFactory.connect(user1).setManager(newManager)).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('should allow owner to set contract manager', async () => {
        await makerFactory.setManager(manager.address);
        expect(await makerFactory.manager()).to.equal(manager.address);
    });
    it('should allow owner to set maker max limit', async () => {
        const newLimit = 3;
        await makerFactory.setMakerMaxLimit(newLimit);
        expect(await makerFactory.makerMaxLimit()).to.equal(newLimit);
    });

    it('should not allow non-owner to set maker max limit', async () => {
        const newLimit = 3;
        await expect(makerFactory.connect(user1).setMakerMaxLimit(newLimit)).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('should allow user to create maker', async () => {
        await makerFactory.connect(user1).createMaker();
        expect(await makerFactory.makerByOwner(user1.address)).to.not.equal(ethers.constants.AddressZero);
    });

    it('should not allow user to create more than maker max limit', async () => {
        const accounts = await ethers.getSigners();
        await makerFactory.setMakerMaxLimit(2);
        await makerFactory.connect(accounts[10]).createMaker();
        await makerFactory.connect(accounts[11]).createMaker();
        await expect(makerFactory.connect(accounts[12]).createMaker()).to.be.revertedWith('Maker creation limit reached');

    });

    it('should not allow user to create more than one maker', async () => {
        await makerFactory.connect(user1).createMaker();
        await expect(makerFactory.connect(user1).createMaker()).to.be.revertedWith('Maker already created for owner');
    });
});
