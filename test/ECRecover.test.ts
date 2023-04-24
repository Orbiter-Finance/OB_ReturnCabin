import * as hardhat from 'hardhat';
describe('ECRecover.test.test.ts', () => {

  it('ECRecover2', async () => {
    const contract = await hardhat.ethers.getContractFactory('ECRecover');
    const makerImplementation = await contract.deploy();
    const instance = await makerImplementation.deployed();
    // tx.chainId=5;
    // tx.nonce=9043;
    // tx.maxPriorityFeePerGas=0;
    // tx.maxFeePerGas=163080267098;
    // tx.gasLimit=21000;
    // tx.to=0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97;
    // tx.value=498364511804194654;
    // tx.v=0;
    // tx.r=33796095646348839706698286744037525328848012927409075992785775263688042363064;
    // tx.s=6745854482740091938698869322187137544536115446507343756918287336418791097234;
    const result = await instance.recoverSigner({
      chainId: 1,
      nonce: 19301,
      maxPriorityFeePerGas: 0,
      maxFeePerGas: '29341551768',
      gasLimit: '21000',
      to: '0xdDf4C5025D1A5742cF12F74eEC246d4432c295e4',
      value: '27862956794010508',
      data: '0x',
      accessList: [],
      r: '0xaf6af34a62ea5f0a7bffbeb8b5a427693d6c697f7c292b2d48972340f859d426',
      s: '0x63b84f8d4facd3acdb273dfa991f4e8269a5ba3b05e840523892ad1eae2c9603',
      v: 1
    });
    console.log(result, '==get==address');
  });
});
