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
        uint256 challengeState; // 1 user challengeSuccess 2 maker challengeSuccess 3 maker no challenge,user withDraw success
    }
    mapping(uint256 => mapping(uint256 => mapping(address => mapping(address => Operations.LPInfo))))
        public pools; // pools
    // challengeInfo: userChallengeState[chainID][txindex]
    mapping(uint256 => mapping(uint256 => userChallengeState)) userChallenge;

    // Action LP usedTokenAmount
    mapping(address => uint256) usedTokenAmount;
    mapping(uint256 => mapping(uint256 => Operations.PoolExt)) public changeExt;

    // LPIndex=>extKey
    uint256 currentExtKey;
    // Action LP usedETHAmount
    uint256 usedETHAmount;
    // user challenge deposit ethBalance
    uint256 userChallengeBalance;

    address owner;

    constructor() {
        currentExtKey = 0;
        console.log("Deploying a OrbiterMakerDeposit with orbiterMakerDeposit");
        // protocal = IOrbiterFactory(msg.sender).protocal;
    }

    fallback() external payable {}

    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner; // owner = maker
    }

    function getpool(
        uint256 fromChainID,
        uint256 toChainID,
        address fromTokenAddress,
        address toTokenAddress
    ) public returns (Operations.LPInfo memory newLp) {
        // get pools all info
    }

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
    ) public override {
        // owner
        require(protocal != address(0), "protocal can not be address(0)");
        require(oneMax > oneMin, "oneMax must be greater than oneMin");

        require(
            pools[fromChainID][toChainID][fromTokenAddress][toTokenAddress]
                .makerAddress == address(0),
            "deposit must be newPair"
        );

        require(
            IOrbiterProtocal(protocal).getDeposit(fromChainID, oneMax) > oneMax,
            "depositAmount must be greater than oneMax"
        );
        getExt(fromChainID, tradingFee, gasFee, oneMin, oneMax, protocal);
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

    function getNewLP(
        uint256 fromChainID,
        uint256 toChainID,
        address fromTokenAddress,
        address toTokenAddress,
        address contractTokenAddress,
        uint256 avalibleETH,
        uint256[] memory times,
        uint256 precision
    ) private {
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

    function getExt(
        uint256 fromChainID,
        uint256 tradingFee,
        uint256 gasFee,
        uint256 oneMin,
        uint256 oneMax,
        address protocal
    ) private {
        uint256 depositAmount = IOrbiterProtocal(protocal).getDeposit(
            fromChainID,
            oneMax
        );
        Operations.PoolExt memory Ext = Operations.PoolExt(
            tradingFee,
            gasFee,
            depositAmount,
            oneMin, // set
            oneMax, // set
            protocal
        );
        // mapping(uint256 => Operations.PoolExt) memory changeExt;
        // Operations.PoolExt[] memory changeExt;
        changeExt[currentExtKey][0] = Ext;
    }

    function LPType(Operations.LPInfo memory readyLPInfo)
        public
        override
        returns (uint256 stateType)
    {
        /* type
          0:never started, avalibleTimes.length = 0
          1:Started but not effective, avalibleTimes.length is odd, nowTime < avalibleTimes[-1]
          2:Started and effective,avalibleTimes.length is odd, nowTime >= avalibleTimes[-1]
          3:Stopped but not effective, avalibleTimes.length is even and not 0，nowTime < avalibleTimes[-1]
          4:Stopped and effect but not over withDrawTime,avalibleTimes.length is even and not 0, nowTime >= avalibleTimes[-1] && nowTime < withDrawTime + avalibleTimes[-1]
          5:Stopped and effect & over withDrawTime,avalibleTimes.length is even and not 0，nowTime >= avalibleTimes[-1] && nowTime >= withDrawTime + avalibleTimes[-1]
         */
        uint256 currentTime = block.timestamp;
        uint256 changeExtIndex = readyLPInfo.avalibleTimes.length % 2 == 1
            ? (readyLPInfo.avalibleTimes.length - 1) / 2
            : readyLPInfo.avalibleTimes.length / 2;
        uint256 withDrawTime = IOrbiterProtocal(
            changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal
        ).maxWithdrawTime();
        if (readyLPInfo.avalibleTimes.length == 0) {
            return 0;
        }
        if (readyLPInfo.avalibleTimes.length % 2 == 1) {
            if (
                currentTime <
                readyLPInfo.avalibleTimes[readyLPInfo.avalibleTimes.length - 1]
            ) {
                return 1;
            } else {
                return 2;
            }
        }
        if (readyLPInfo.avalibleTimes.length % 2 == 0) {
            if (
                currentTime <
                readyLPInfo.avalibleTimes[readyLPInfo.avalibleTimes.length - 1]
            ) {
                return 3;
            } else {
                if (
                    currentTime <
                    withDrawTime +
                        readyLPInfo.avalibleTimes[
                            readyLPInfo.avalibleTimes.length - 1
                        ]
                ) {
                    return 4;
                } else {
                    return 5;
                }
            }
        }
    }

    function LPAction(
        uint256 fromChainID,
        uint256 toChainID,
        address fromTokenAddress,
        address toTokenAddress,
        address contractTokenAddress
    ) public override returns (bool success) {
        /*
        permission：owner
        require lp_type: 0.5.6

        1. Token balance judgment
            1.1 According to lpinfo.contractTokenAddress, get the token balance 
              1.1.1 ERC20ContractAddress
                tokenContract.balanceof(address(this))
                IERC20 liquidityToken = IERC20(contractTokenAddress);
                uint256 liquidityTokenAmount = liquidityToken.balance(address(this));
                require(lpinfo.changeExt[lpinfo.changExtKey][ExtIndex].avalibleDeposit < liquidityTokenAmount - usedTokenAmount[fromTokenAddress]);
              1.1.2 address(0):ETH
                ***.balanceof(address(this))
          2.3 ETH balance judgment：
              ***.balanceof(address(this)) Get the ETH balance of the contract address
              uint256 liquidityETHAmount = ***.balance(address(this));
              require(lpinfo.changeExt[lpinfo.changExtKey][ExtIndex].avalibleETH  < liquidityETHAmount - usedETHAmount - userChallengeBalance);
        3.Started successfully
          3.1 The start timestamp needs to be delayed by time based on the current block time, and time is obtained from orbiterManager.
              readyLPInfo.avalibleTimes.push(block.timestamp + orbiterManager(manageraddress).getStartDealyTime())
          3.2 lpinfo.canStart = false 
          3.3 usedTokenAmount(contractTokenAddress) += lpinfo.changeExt[lpinfo.changExtKey][ExtIndex].avalibleDeposit
          3.4 usedETHAmount += lpinfo.changeExt[lpinfo.changExtKey][ExtIndex].avalibleETH
      */
        // require(
        //     fromTokenAddress != address(0),
        //     "fromTokenAddress can not be address(0)"
        // );
        // require(
        //     toTokenAddress != address(0),
        //     "toTokenAddress can not be address(0)"
        // );

        Operations.LPInfo storage readyLPInfo = pools[fromChainID][toChainID][
            fromTokenAddress
        ][toTokenAddress];

        require(readyLPInfo.canStart == true, "LPInfo must be stop state");

        console.log("zz =", LPType(readyLPInfo));

        require(
            LPType(readyLPInfo) == 0 ||
                LPType(readyLPInfo) == 5 ||
                LPType(readyLPInfo) == 6,
            "LPType must be 0,5,6"
        );

        uint256 liquidityTokenAmount;
        uint256 liquidityETHAmount;

        if (contractTokenAddress != address(0)) {
            // ERC20
            IERC20 liquidityToken = IERC20(readyLPInfo.contractTokenAddress);
            liquidityTokenAmount = liquidityToken.balanceOf(address(this));
            liquidityETHAmount = address(this).balance;
        } else {
            liquidityTokenAmount = address(this).balance;
            liquidityETHAmount = address(this).balance;
        }

        //=============//
        uint256 changeExtIndex = readyLPInfo.avalibleTimes.length % 2 == 1
            ? (readyLPInfo.avalibleTimes.length - 1) / 2
            : readyLPInfo.avalibleTimes.length / 2;
        if (
            changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal ==
            address(0)
        ) {
            changeExt[readyLPInfo.changExtKey][changeExtIndex] = changeExt[
                readyLPInfo.changExtKey
            ][changeExtIndex - 1];
        }
        console.log(
            "protocal =",
            changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal
        );
        console.log(
            "avalibleDeposit =",
            changeExt[readyLPInfo.changExtKey][changeExtIndex].avalibleDeposit
        );
        console.log("usedTokenAmount =", usedTokenAmount[contractTokenAddress]);
        console.log("address =", address(this));

        console.log("avalibleETH =", readyLPInfo.avalibleETH);
        console.log("liquidityETHAmount =", liquidityETHAmount);
        console.log("usedETHAmount =", usedETHAmount);
        console.log("userChallengeBalance =", userChallengeBalance);

        if (contractTokenAddress != address(0)) {
            require(
                changeExt[readyLPInfo.changExtKey][changeExtIndex]
                    .avalibleDeposit <
                    liquidityTokenAmount -
                        usedTokenAmount[contractTokenAddress],
                "token not enough"
            );
            require(
                readyLPInfo.avalibleETH <
                    liquidityETHAmount - usedETHAmount - userChallengeBalance,
                "ETH not enough"
            );
        } else {
            require(
                changeExt[readyLPInfo.changExtKey][changeExtIndex]
                    .avalibleDeposit <
                    liquidityTokenAmount -
                        usedTokenAmount[contractTokenAddress] -
                        usedETHAmount -
                        userChallengeBalance,
                "liquidityETHAmount not enough"
            );
            require(
                readyLPInfo.avalibleETH <
                    liquidityETHAmount -
                        usedTokenAmount[contractTokenAddress] -
                        usedETHAmount -
                        userChallengeBalance,
                "avalibleETH not enough"
            );
        }

        readyLPInfo.avalibleTimes.push(
            block.timestamp +
                IOrbiterProtocal(
                    changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal
                ).getStartDealyTime(fromChainID)
        );
        readyLPInfo.canStart = false;
        usedTokenAmount[contractTokenAddress] += changeExt[
            readyLPInfo.changExtKey
        ][changeExtIndex].avalibleDeposit;
        usedETHAmount += readyLPInfo.avalibleETH;
        console.log("usedTokenAmount =", usedTokenAmount[contractTokenAddress]);
        console.log("usedETHAmount =", usedETHAmount);
        return true;
    }

    function LPStop(
        uint256 fromChainID,
        uint256 toChainID,
        address fromTokenAddress,
        address toTokenAddress
    ) public override returns (bool success) {
        /*
        permission：owner
        require lp_type: 2

        1.getLPINFo
        3.stop Success
          3.1 stopTime，Need to delay time based on the current block time, time is obtained from protocolV1
              readyLPInfo.avalibleTimes.push(block.timestamp + procotol(protocal).getStopDealyTime())
          3.2 lpinfo.canStart = true
      */
        Operations.LPInfo storage readyLPInfo = pools[fromChainID][toChainID][
            fromTokenAddress
        ][toTokenAddress];
        // type = 2
        require(LPType(readyLPInfo) == 2, "LPType must be 2");
        uint256 changeExtIndex = (readyLPInfo.avalibleTimes.length - 1) / 2;
        // stopTime
        readyLPInfo.avalibleTimes.push(
            block.timestamp +
                IOrbiterProtocal(
                    changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal
                ).getStopDealyTime(fromChainID)
        );
        readyLPInfo.canStart = true;
        return true;
    }

    /*
     dev
     */
    function releaseLPLiquidity(
        uint256 fromChainID,
        uint256 toChainID,
        address fromTokenAddress,
        address toTokenAddress
    ) public override {
        require(
            fromTokenAddress != address(0),
            "fromTokenAddress can not be address(0)"
        );
        require(
            toTokenAddress != address(0),
            "toTokenAddress can not be address(0)"
        );

        Operations.LPInfo memory readyLPInfo = pools[fromChainID][toChainID][
            fromTokenAddress
        ][toTokenAddress];
        require(LPType(readyLPInfo) == 6, "LPType must be 6");
    }

    /*
      dev
    */
    function makerWithdraw(
        address contractTokenAddress,
        uint256 withDrawETHAmount,
        uint256 withDrawTokenAmount
    ) public override {
        require(
            withDrawETHAmount >= 0,
            "withDrawETHAmount must be greater than 0"
        );
        require(
            withDrawTokenAmount >= 0,
            "withDrawTokenAmount must be greater than 0"
        );

        IERC20 withDrawToken = IERC20(contractTokenAddress);
        uint256 tokenBalance = withDrawToken.balanceOf(address(this));
        require(
            withDrawTokenAmount <
                tokenBalance - usedTokenAmount[contractTokenAddress]
        );

        uint256 ETHBalance = address(this).balance;
        require(
            withDrawETHAmount <
                ETHBalance - usedETHAmount - userChallengeBalance
        );

        withDrawToken.transferFrom(
            address(this),
            msg.sender,
            withDrawTokenAmount
        );
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
    ) public override returns (bool success) {
        /*
        permission：owner
        require lp_type: 0,4,5
        1.get LPINFO，
        2.generate newChangeExt
        */
        Operations.LPInfo memory readyLPInfo = pools[fromChainID][toChainID][
            fromTokenAddress
        ][toTokenAddress];

        require(
            LPType(readyLPInfo) == 0 ||
                LPType(readyLPInfo) == 4 ||
                LPType(readyLPInfo) == 5,
            "LPType must be 0||4||5"
        );

        uint256 changeExtIndex = (readyLPInfo.avalibleTimes.length - 1) / 2;

        require(
            changeExt[readyLPInfo.changExtKey][changeExtIndex].onemin != 0,
            "onemin can not be 0"
        );

        uint256 oneMax = _oneMax <= 0
            ? changeExt[readyLPInfo.changExtKey][changeExtIndex].onemax
            : _oneMax;

        uint256 depositAmount = IOrbiterProtocal(
            changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal
        ).getDeposit(fromChainID, oneMax);
        require(oneMax > 0, "oneMax must be greater than 0");
        require(
            oneMax < depositAmount,
            "oneMax must be less than depostAmount"
        );

        Operations.PoolExt memory Ext = Operations.PoolExt(
            _tradingFee <= 0
                ? changeExt[readyLPInfo.changExtKey][changeExtIndex].tradingFee
                : _tradingFee,
            _gasFee <= 0
                ? changeExt[readyLPInfo.changExtKey][changeExtIndex].onemin
                : _gasFee,
            depositAmount,
            _oneMin <= 0
                ? changeExt[readyLPInfo.changExtKey][changeExtIndex].onemin
                : _oneMin,
            oneMax,
            _protocal == address(0)
                ? changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal
                : _protocal
        );
        uint256 currentKey = readyLPInfo.avalibleTimes.length / 2;

        changeExt[readyLPInfo.changExtKey][currentKey] = Ext;
        return true;
    }

    function userChallengeAction(
        uint256 fromChainID,
        uint256 TxIndex,
        uint256 toChainID,
        address fromTokenAddress,
        address toTokenAddress,
        address contractTokenAddress,
        uint256 changeExtIndex
    ) public override returns (bool success) {
        // how to do?
        // uint256 userChallengeBalance
        // The fee needs to be prepaid and transferred to the method of using ETH for the user as a notification, the amount
        // userChallengeBalance += m
        require(
            userChallenge[fromChainID][TxIndex].challengeState == 0,
            "challenge is new"
        );

        Operations.LPInfo memory readyLPInfo = pools[fromChainID][toChainID][
            fromTokenAddress
        ][toTokenAddress];
        require(
            readyLPInfo.avalibleTimes.length != 0,
            "readyLPInfo.avalibleTimes.length must be greater than 0"
        );
        bool userChallengeSituation = IOrbiterProtocal(
            changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal
        ).checkUserChallenge(
                msg.sender,
                fromChainID,
                TxIndex,
                changeExtIndex,
                toChainID,
                readyLPInfo,
                changeExt[readyLPInfo.changExtKey][changeExtIndex]
            );
        require(userChallengeSituation == true, "userChallenge must be true");
        userChallengeState memory challengeInfo = userChallengeState(
            changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal,
            contractTokenAddress,
            block.timestamp,
            1
        );
        userChallenge[fromChainID][TxIndex] = challengeInfo;
        return true;
    }

    function makerChanllenge(
        uint256 fromChainID,
        uint256 fromTxIndex,
        uint256 toChainID,
        uint256 toTxIndex,
        address fromTokenAddress,
        address toTokenAddress,
        address contractTokenAddress,
        uint256 changeExtIndex
    ) public override returns (bool success) {
        require(
            userChallenge[fromChainID][fromTxIndex].challengeState == 1,
            "challenge state must be 1"
        );

        Operations.LPInfo memory readyLPInfo = pools[fromChainID][toChainID][
            fromTokenAddress
        ][toTokenAddress];
        require(readyLPInfo.avalibleTimes.length != 0, "have LPinfo");
        bool makerChallenge = IOrbiterProtocal(
            changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal
        ).checkMakerChallenge(
                fromChainID,
                fromTxIndex,
                changeExtIndex,
                toChainID,
                toTxIndex,
                readyLPInfo,
                changeExt[readyLPInfo.changExtKey][changeExtIndex]
            );
        require(makerChallenge == true, "makerChanllenge must be true");
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
    ) public override returns (bool success) {
        /*
        1 Verify the correctness of the transaction ========== （implemented in the protocolContract）
          1.1 Take out the proven event implementation => (The verification is performed in the Extractor, and the verification is successful (proving that the event occurred on the chain), and the input parameters need to be given.）
            1.1.1  ProtocalV1: getTxInfo(chainID，TxIndx)retruns(txinfo)  =======  Get txinfo in protocal
          1.2 Prove that txinfo events comply with market maker rules (LPINFO) ============= Prove in protocal and return success or not
        2 Stored in the accepted data structure
          2.1
          challengeTime
          challengeState
          mapping (uint256 => mapping(uint256 => userChallengeState)) userChallenge;
          userChallenge[chainID][TxIndex] = userChallengeState(
            tokenAddress,
            protocalAddress,
            challengeTime,
            challengeState = 1
          )
          struct {
            tokenAddress,
            protocalAddress,
            challengeTime,
            challengeState, // 1 user challengeSuccess 2 maker challengeSuccess 3 maker no challenge,user withDraw success
          } userChallengeState;
      */
        require(
            userChallenge[fromChainID][TxIndex].challengeState == 1,
            "have challengeInfo and state is not 1"
        );

        Operations.LPInfo memory readyLPInfo = pools[fromChainID][toChainID][
            fromTokenAddress
        ][toTokenAddress];
        console.log("nowTime =", block.timestamp);
        console.log(
            "challengeTime =",
            userChallenge[fromChainID][TxIndex].challengeTime
        );
        console.log(
            "disputeTime =",
            IOrbiterProtocal(
                changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal
            ).getDisputeTimeTime(fromChainID)
        );
        require(
            block.timestamp >
                userChallenge[fromChainID][TxIndex].challengeTime +
                    IOrbiterProtocal(
                        changeExt[readyLPInfo.changExtKey][changeExtIndex]
                            .protocal
                    ).getDisputeTimeTime(fromChainID),
            "nowTime must greater than challengeTime"
        );
        (
            bool userWithDraw,
            uint256 eAmount,
            uint256 tAmount
        ) = IOrbiterProtocal(
                changeExt[readyLPInfo.changExtKey][changeExtIndex].protocal
            ).userChanllengeWithDraw(
                    msg.sender,
                    fromChainID,
                    TxIndex,
                    changeExtIndex,
                    toChainID,
                    readyLPInfo
                );
        require(userWithDraw == true, "userWithDraw must be true");

        console.log(
            "liquidityTokenAmount =",
            IERC20(contractTokenAddress).balanceOf(address(this))
        );
        console.log("liquidityETHAmount =", address(this).balance);
        console.log("userWithDraw =", userWithDraw);
        console.log("eAmount =", eAmount);
        console.log("tAmount =", tAmount);

        if (tAmount > 0) {
            require(
                IERC20(contractTokenAddress).balanceOf(address(this)) > tAmount,
                "liquidityTokenAmount must greater than tAmount"
            );
            IERC20(contractTokenAddress).transfer(msg.sender, tAmount);
        }

        if (eAmount > 0) {
            require(
                address(this).balance > eAmount,
                "liquidityETHAmount must greater than eAmount"
            );
            msg.sender.transfer(eAmount);
        }

        userChallenge[fromChainID][TxIndex].challengeState = 3;
    }
}
