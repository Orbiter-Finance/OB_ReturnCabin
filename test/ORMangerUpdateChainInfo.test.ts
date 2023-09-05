import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from 'hardhat';
import lodash from "lodash";
import { BridgeLib, ORManager } from "../typechain-types/contracts/ORManager";
import { defaultChainInfoArray, testToken, chainIDgetTokenSequence, calculateMainnetToken, initTestToken } from "./lib/mockData";
import { embedVersionIncreaseAndEnableTime, getMinEnableTime } from "./utils.test";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ORManager__factory } from "../typechain-types";



describe('ORMangerUpdateChainInfo', () => {
  let signers: SignerWithAddress[];
  let orManager: ORManager;
  before(async function () {
    signers = await ethers.getSigners();
    initTestToken();

    if(process.env['OR_MANAGER_ADDRESS'] == undefined) {
      orManager = await new ORManager__factory(signers[0]).deploy(
        signers[1].address,
      );
      await orManager.deployed();
      process.env['OR_MANAGER_ADDRESS'] = orManager.address;
    } else {
      orManager = new ORManager__factory(signers[0]).attach(
        process.env['OR_MANAGER_ADDRESS'] as string,
      );
    }
    console.log('Address of orManager contract:', orManager.address);

  });

  it(
    'Function updateChainTokens should succeed',
    embedVersionIncreaseAndEnableTime(
      () => orManager.getVersionAndEnableTime().then((r) => r.version),
      async function () {
        const chainIds = defaultChainInfoArray.flatMap((chainInfo) =>
          Array.from({ length: testToken.MAINNET_TOKEN.length }, () =>
            Number(chainInfo.id),
          ),
        );
        const tokens: BridgeLib.TokenInfoStruct[] = [];

        for (let i = 0; i < defaultChainInfoArray.length; i++) {
          for (let j = 0; j < testToken.MAINNET_TOKEN.length; j++) {
            const chainInfo = defaultChainInfoArray[i];
            const chainId = Number(chainInfo.id);
            const token = chainIDgetTokenSequence(chainId, j);
            const mainnetTestToken = calculateMainnetToken(chainId, token);
            tokens.push({
              token: BigNumber.from(token).add(0), // add(0), convert _hex uppercase to lowercase
              mainnetToken: mainnetTestToken,
              decimals: 18,
            });
          }
        }

        console.log(
          'current chainIds:',
          chainIds.map((chainId) => chainId.toString()),
          'register tokens:',
          tokens.map((token) => BigNumber.from(token.token).toHexString()),
          'mainnetTokens:',
          tokens.map((token) => token.mainnetToken),
        );

        const { events } = await orManager
          .updateChainTokens(getMinEnableTime(), chainIds, tokens)
          .then((t) => t.wait());

        (events || []).forEach((event, i) => {
          expect(event.args?.id).to.eq(chainIds[i]);
          expect(lodash.toPlainObject(event.args?.tokenInfo)).to.deep.includes(
            tokens[i],
          );
        });

        const latestIndex = tokens.length - 1;
        const tokenInfo = await orManager.getChainTokenInfo(
          chainIds[latestIndex],
          tokens[latestIndex].token,
        );
        expect(lodash.toPlainObject(tokenInfo)).to.deep.includes(
          tokens[latestIndex],
        );
      },
    ),
  );



});
