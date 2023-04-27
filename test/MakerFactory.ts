import { ethers } from 'hardhat';
import { expect } from 'chai';
import { MakerFactory } from '../typechain-types';

describe('MakerFactory', () => {
    let makerFactory: MakerFactory;
    let owner;
    let user1: any;
    let user2;

    beforeEach(async () => {
        const [signer1, signer2, signer3] = await ethers.getSigners();
        owner = signer1;
        user1 = signer2;
        user2 = signer3;
        //
        let MakerDeposit = await ethers.getContractFactory('MakerDeposit');
        const makerDeposit= await MakerDeposit.deploy()
        await makerDeposit.deployed();

        const MakerFactory = await ethers.getContractFactory('MakerFactory', owner);
        makerFactory = await MakerFactory.deploy(owner.address, 2, makerDeposit.address);
        await makerFactory.deployed();
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
        await makerFactory.connect(accounts[10]).createMaker();
        await makerFactory.connect(accounts[11]).createMaker();
        await expect(makerFactory.connect(accounts[12]).createMaker()).to.be.revertedWith('Maker creation limit reached');

    });

    it('should not allow user to create more than one maker', async () => {
        await makerFactory.connect(user1).createMaker();
        await expect(makerFactory.connect(user1).createMaker()).to.be.revertedWith('Maker already created for owner');
    });

    it('should Already initialized', async () => {
        await makerFactory.connect(user1).createMaker();
        const makerAddr = await makerFactory.makerByOwner(user1.address);
        await expect(makerAddr).not.empty
        const makerDeposit = await ethers.getContractAt("MakerDeposit", makerAddr);
        await expect(makerDeposit.initialize(user1.address)).to.be.revertedWith('Already initialized');
    });

});
