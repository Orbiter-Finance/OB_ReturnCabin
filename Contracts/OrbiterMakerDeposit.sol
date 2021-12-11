// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import "hardhat/console.sol";
import "./interfaces/IOrbiterMakerDeposit.sol";
import "./interfaces/IOrbiterFactory.sol";
import "./interfaces/IOrbiterProtocal.sol";
import "./interfaces/IERC20.sol";
import "./Operations.sol";

contract OrbiterMakerDeposit is IOrbiterMakerDeposit {
    struct userChallengeState {
        address tokenAddress;
        address protocalAddress;
        uint256 challengeTime;
        uint256 challengeState;
    }
    mapping(uint256 => mapping(uint256 => mapping(address => mapping(address => Operations.LPInfo))))
        public pools;
    mapping (uint256 => mapping(uint256 => userChallengeState)) userChallenge;
    mapping (address=>uint256) usedTokenAmount;
    mapping (uint256 => mapping (uint256=>Operations.PoolExt)) public changeExt;

    uint256 currentExtKey;
    uint256 usedETHAmount;
    uint256 userChallengeBalance;

    address _owner;

    constructor() {
        currentExtKey = 0;
        console.log("Deploying a OrbiterMakerDeposit with orbiterMakerDeposit");
        // protocal = IOrbiterFactory(msg.sender).protocal;
    }

    fallback() external payable {}
    function createLPInfo(
        uint256 fromChainID,
        uint256 toChainID,
        address fromTokenAddress,
        address toTokenAddress,
        address contractTokenAddress,
        uint256 avalibleETH,
        uint256 oneMax,
        uint256 oneMin,
        uint256 tradingFee,
        uint256 gasFee,
        address protocal,
        uint256 precision
    ) override public {
        // owner
        require(protocal != address(0), "protocal can not be address(0)");
        require(oneMax > oneMin, "oneMax must be greater than oneMin");

        require(
            pools[fromChainID][toChainID][fromTokenAddress][toTokenAddress]
                .makerAddress == address(0),
            "deposit must be newPair"
        );

        require(IOrbiterProtocal(protocal).getDeposit(fromChainID,oneMax) > oneMax, "depositAmount must be greater than oneMax");
        getExt(fromChainID,tradingFee,gasFee,oneMin,oneMax,protocal);
        uint256[] memory times;
        getNewLP(
              fromChainID,
              toChainID,
              fromTokenAddress,
              toTokenAddress,
              contractTokenAddress,
              avalibleETH,
              times,
              precision
        );
    }

    function getNewLP(uint256 fromChainID,
                      uint256 toChainID,
                      address fromTokenAddress,
                      address toTokenAddress,
                      address contractTokenAddress,
                      uint256 avalibleETH,
                      uint256[] memory times,
                      uint256 precision) 
            private {
        Operations.LPInfo memory newLp = Operations.LPInfo(
              msg.sender,
              fromChainID,
              toChainID,
              fromTokenAddress,
              toTokenAddress,
              contractTokenAddress,
              avalibleETH,
              currentExtKey,
              precision,
              true,
              times
        );
        pools[fromChainID][toChainID][fromTokenAddress][toTokenAddress] = newLp;
        currentExtKey++;
    }

    function getExt(uint256 fromChainID,
                    uint256 tradingFee,
                    uint256 gasFee,
                    uint256 oneMin,
                    uint256 oneMax,
                    address protocal) 
            private {
        uint256 depositAmount = IOrbiterProtocal(protocal).getDeposit(
            fromChainID,
            oneMax
        );
        Operations.PoolExt memory Ext = Operations.PoolExt(
          tradingFee,
          gasFee,
          depositAmount,
          oneMin,
          oneMax,
          protocal
        );
        changeExt[currentExtKey][0] = Ext;
    }

    function LPType(Operations.LPInfo memory readyLPInfo) override public returns(uint256 stateType){
      uint256 currentTime = block.timestamp;
      uint256 changeExtIndex = readyLPInfo.avalibleTimes.length % 2 == 1 ? (readyLPInfo.avalibleTimes.length - 1) / 2 : readyLPInfo.avalibleTimes.length / 2;
      uint256 withDrawTime = IOrbiterProtocal(changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal).maxWithdrawTime();
      if (readyLPInfo.avalibleTimes.length == 0) {
        return 0;
      }
      if (readyLPInfo.avalibleTimes.length % 2 == 1) {
        if (currentTime < readyLPInfo.avalibleTimes[readyLPInfo.avalibleTimes.length - 1]) {
          return 1;
        } else {
          return 2;
        }
      }
      if (readyLPInfo.avalibleTimes.length % 2 == 0) {
        if (currentTime < readyLPInfo.avalibleTimes[readyLPInfo.avalibleTimes.length - 1]) {
          return 3;
        } else {
          if (currentTime < withDrawTime + readyLPInfo.avalibleTimes[readyLPInfo.avalibleTimes.length - 1]) {
            return 4;
          }
          else {
            return 5;
          }
        }
      }
    }

    function LPAction(uint256 fromChainID,uint256 toChainID,address fromTokenAddress, address toTokenAddress, address contractTokenAddress) override public returns(bool success) {
      require(fromTokenAddress != address(0), "fromTokenAddress can not be address(0)");
      require(toTokenAddress != address(0), "toTokenAddress can not be address(0)");

      Operations.LPInfo storage readyLPInfo = pools[fromChainID][toChainID][fromTokenAddress][toTokenAddress];

      require(readyLPInfo.canStart == true, "LPInfo must be stop state");

      console.log('zz =',LPType(readyLPInfo));

      require(LPType(readyLPInfo) == 0 || LPType(readyLPInfo) == 5 || LPType(readyLPInfo) == 6, 'LPType must be 0,5,6');

      IERC20 liquidityToken = IERC20(readyLPInfo.contractTokenAddress);
      uint256 liquidityTokenAmount = liquidityToken.balanceOf(address(this));
      console.log('liquidityTokenAmount =',liquidityTokenAmount);
      uint256 liquidityETHAmount = address(this).balance;
      console.log('liquidityETHAmount =',liquidityETHAmount);

      //=============//
      uint256 changeExtIndex = readyLPInfo.avalibleTimes.length % 2 == 1 ? (readyLPInfo.avalibleTimes.length - 1) / 2 : readyLPInfo.avalibleTimes.length / 2;
      if (changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal == address(0)) {
        changeExt[readyLPInfo.changExtKey][changeExtIndex] = changeExt[readyLPInfo.changExtKey][changeExtIndex - 1];
      }
      console.log('protocal =',changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal);
      console.log('avalibleDeposit =',changeExt[readyLPInfo.changExtKey][changeExtIndex].avalibleDeposit);
      console.log('usedTokenAmount =',usedTokenAmount[fromTokenAddress]);
      console.log('address =',address(this));


      console.log('avalibleETH =',readyLPInfo.avalibleETH);
      console.log('liquidityETHAmount =',liquidityETHAmount);
      console.log('usedETHAmount =',usedETHAmount);
      console.log('userChallengeBalance =',userChallengeBalance);

      // console.log('111 =',address(this).balance);
      // console.log('222 =',msg.sender.balance);
      // msg.sender.transfer(1000000);

      require(changeExt[readyLPInfo.changExtKey][changeExtIndex].avalibleDeposit < liquidityTokenAmount - usedTokenAmount[fromTokenAddress],'token not enough');
      // require(readyLPInfo.avalibleETH  < liquidityETHAmount - usedETHAmount - userChallengeBalance, 'ETH not enough');

      readyLPInfo.avalibleTimes.push(block.timestamp + IOrbiterProtocal(changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal).getStartDealyTime(fromChainID));
      readyLPInfo.canStart = false;
      usedTokenAmount[contractTokenAddress] += changeExt[readyLPInfo.changExtKey][changeExtIndex].avalibleDeposit;
      usedETHAmount += readyLPInfo.avalibleETH;
      console.log('usedTokenAmount =',usedTokenAmount[contractTokenAddress]);
      console.log('usedETHAmount =',usedETHAmount);
      return true;
    }

    function LPStop(uint256 fromChainID,uint256 toChainID,address fromTokenAddress, address toTokenAddress) override public returns(bool success) {
      require(fromTokenAddress != address(0), "fromTokenAddress can not be address(0)");
      require(toTokenAddress != address(0), "toTokenAddress can not be address(0)");

      Operations.LPInfo storage readyLPInfo = pools[fromChainID][toChainID][fromTokenAddress][toTokenAddress];

      require(readyLPInfo.avalibleTimes.length % 2 == 1, "LPInfo avalibleTimes must be odd number");
      require(LPType(readyLPInfo) == 2, 'LPType must be 2');
      uint256 useKey = (readyLPInfo.avalibleTimes.length - 1) / 2;
      readyLPInfo.avalibleTimes.push(block.timestamp + IOrbiterProtocal(changeExt[readyLPInfo.changExtKey][useKey].protocal).getStopDealyTime(fromChainID));
      readyLPInfo.canStart = true;
      return true;
    }


    function releaseLPLiquidity(uint256 fromChainID,uint256 toChainID,address fromTokenAddress, address toTokenAddress) override public {
      require(fromTokenAddress != address(0), "fromTokenAddress can not be address(0)");
      require(toTokenAddress != address(0), "toTokenAddress can not be address(0)");

      Operations.LPInfo memory readyLPInfo = pools[fromChainID][toChainID][fromTokenAddress][toTokenAddress];
      require(LPType(readyLPInfo) == 6, 'LPType must be 6');
    }


    function makerWithdraw(
        address contractTokenAddress,
        uint256 withDrawETHAmount,
        uint256 withDrawTokenAmount
    ) override public {
      require(contractTokenAddress != address(0), 'contractTokenAddress can not be address(0)');
      require(withDrawETHAmount >= 0, 'withDrawETHAmount must be greater than 0');
      require(withDrawTokenAmount >= 0, 'withDrawTokenAmount must be greater than 0');


      IERC20 withDrawToken = IERC20(contractTokenAddress);
      uint256 tokenBalance = withDrawToken.balanceOf(address(this));
      require(withDrawTokenAmount < tokenBalance - usedTokenAmount[contractTokenAddress]);

      uint256 ETHBalance = address(this).balance;
      require(withDrawETHAmount  < ETHBalance - usedETHAmount - userChallengeBalance);


      withDrawToken.transferFrom(address(this), msg.sender, withDrawTokenAmount);
      msg.sender.transfer(withDrawETHAmount);
    }

    function LPUpdate(
        uint256 fromChainID,
        uint256 toChainID,
        address fromTokenAddress,
        address toTokenAddress,
        uint256 _oneMax,
        uint256 _oneMin,
        uint256 _tradingFee,
        uint256 _gasFee,
        address _protocal
      ) override public returns(bool success){
      require(fromTokenAddress != address(0), "fromTokenAddress can not be address(0)");
      require(toTokenAddress != address(0), "toTokenAddress can not be address(0)");

      Operations.LPInfo memory readyLPInfo = pools[fromChainID][toChainID][fromTokenAddress][toTokenAddress];

      require(LPType(readyLPInfo) == 0 || LPType(readyLPInfo) == 4 || LPType(readyLPInfo) == 5, 'LPType must be 0||4||5');


      uint256 useKey = (readyLPInfo.avalibleTimes.length - 1) / 2;

      require(changeExt[readyLPInfo.changExtKey][useKey].onemin != 0, "onemin can not be 0");

      uint256 oneMax = _oneMax <= 0 ? changeExt[readyLPInfo.changExtKey][useKey].onemax : _oneMax;

      uint256 depositAmount = IOrbiterProtocal(changeExt[readyLPInfo.changExtKey][useKey].protocal).getDeposit(
          fromChainID,
          oneMax
      );
      require(oneMax > 0, "oneMax must be greater than 0");
      // require(oneMax > oneMin, "oneMax must be greater than oneMin");
      // require(oneMax < depositAmount, "oneMax must be less than depostAmount");

      Operations.PoolExt memory Ext = Operations.PoolExt(
        _tradingFee <= 0 ? changeExt[readyLPInfo.changExtKey][useKey].tradingFee : _tradingFee,
        // tradingFee,
        // gasFee,
        _gasFee <= 0 ? changeExt[readyLPInfo.changExtKey][useKey].onemin : _gasFee,
        depositAmount,
        _oneMin <= 0 ? changeExt[readyLPInfo.changExtKey][useKey].onemin : _oneMin,
        // oneMin,
        oneMax,
        _protocal == address(0) ? changeExt[readyLPInfo.changExtKey][useKey].protocal : _protocal
        // protocal
      );
      uint256 currentKey = readyLPInfo.avalibleTimes.length / 2;

      changeExt[readyLPInfo.changExtKey][currentKey] = Ext;
      return true;
    }

    function userChallengeAction(uint256 fromChainID,uint256 TxIndex,uint256 toChainID,address fromTokenAddress, address toTokenAddress,address contractTokenAddress,uint256 changeExtIndex) override public returns(bool success){
      require(contractTokenAddress != address(0), "contractTokenAddress can not be address(0)");
      require(fromTokenAddress != address(0), "fromTokenAddress can not be address(0)");
      require(toTokenAddress != address(0), "toTokenAddress can not be address(0)");
      require(userChallenge[fromChainID][TxIndex].challengeState == 0, 'challenge is new');

      Operations.LPInfo memory readyLPInfo = pools[fromChainID][toChainID][fromTokenAddress][toTokenAddress];
      console.log('000000000000000 =',readyLPInfo.avalibleTimes.length);
      console.log('000000000000000 =',readyLPInfo.avalibleTimes[0]);
      require(readyLPInfo.avalibleTimes.length != 0, "readyLPInfo.avalibleTimes.length must be greater than 0");
      bool userChallengeSituation = IOrbiterProtocal(changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal).checkUserChallenge(msg.sender,fromChainID,TxIndex,changeExtIndex,toChainID,readyLPInfo,changeExt[readyLPInfo.changExtKey][changeExtIndex]);
      require(userChallengeSituation == true, 'userChallenge must be true');
      userChallengeState memory challengeInfo = userChallengeState(
        changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal,
        contractTokenAddress,
        block.timestamp,
        1
      );
      userChallenge[fromChainID][TxIndex] = challengeInfo;
      return true;
    }

    function makerChanllenge(uint256 fromChainID,uint256 fromTxIndex,uint256 toChainID,uint256 toTxIndex,address fromTokenAddress,address toTokenAddress,address contractTokenAddress,uint256 changeExtIndex) override public returns(bool success) {
      require(contractTokenAddress != address(0), "contractTokenAddress can not be address(0)");
      require(fromTokenAddress != address(0), "fromTokenAddress can not be address(0)");
      require(toTokenAddress != address(0), "toTokenAddress can not be address(0)");
      require(userChallenge[fromChainID][fromTxIndex].challengeState == 1, 'challenge state must be 1');

      Operations.LPInfo memory readyLPInfo = pools[fromChainID][toChainID][fromTokenAddress][toTokenAddress];
      require(readyLPInfo.avalibleTimes.length != 0, "have LPinfo");
      bool makerChallenge = IOrbiterProtocal(changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal).checkMakerChallenge(fromChainID,fromTxIndex,changeExtIndex,toChainID,toTxIndex,readyLPInfo,changeExt[readyLPInfo.changExtKey][changeExtIndex]);
      require(makerChallenge == true, 'makerChanllenge must be true');
      userChallenge[fromChainID][fromTxIndex].challengeState = 2;
      return true;
    }

    function userChanllengeWithDraw(
            uint256 fromChainID,
            uint256 TxIndex,
            uint256 toChainID,
            address fromTokenAddress,
            address toTokenAddress,
            uint256 changeExtIndex,
            address contractTokenAddress
      ) override public returns(bool success){
      require(fromTokenAddress != address(0), "fromTokenAddress can not be address(0)");
      require(toTokenAddress != address(0), "toTokenAddress can not be address(0)");
      require(contractTokenAddress != address(0), "contractTokenAddress can not be address(0)");

      require(userChallenge[fromChainID][TxIndex].challengeState == 1, 'have challengeInfo and state is not 1');

      Operations.LPInfo memory readyLPInfo = pools[fromChainID][toChainID][fromTokenAddress][toTokenAddress];
      console.log('nowTime =',block.timestamp);
      console.log('challengeTime =',userChallenge[fromChainID][TxIndex].challengeTime);
      console.log('disputeTime =',IOrbiterProtocal(changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal).getDisputeTimeTime(fromChainID));
      require(block.timestamp > userChallenge[fromChainID][TxIndex].challengeTime + IOrbiterProtocal(changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal).getDisputeTimeTime(fromChainID), 'nowTime must greater than challengeTime');
      (bool userWithDraw, uint eAmount, uint tAmount) = IOrbiterProtocal(changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal).userChanllengeWithDraw(msg.sender, fromChainID,TxIndex,changeExtIndex,toChainID,readyLPInfo);
      require(userWithDraw ==  true, 'userWithDraw must be true');

      console.log('liquidityTokenAmount =',IERC20(contractTokenAddress).balanceOf(address(this)));
      console.log('liquidityETHAmount =',address(this).balance);
      console.log('userWithDraw =',userWithDraw);
      console.log('eAmount =',eAmount);
      console.log('tAmount =',tAmount);

      // require(address(this).balance > eAmount, "liquidityETHAmount must greater than eAmount");
      require(IERC20(contractTokenAddress).balanceOf(address(this)) > tAmount, "liquidityTokenAmount must greater than tAmount");

      IERC20(contractTokenAddress).transfer(msg.sender, tAmount);
      // msg.sender.transfer(eAmount);
      userChallenge[fromChainID][TxIndex].challengeState = 3;
    }
}
