// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import "hardhat/console.sol";
import "./interfaces/IOrbiterExtrator.sol";
import "./interfaces/IOrbiterMakerDeposit.sol";
import "./interfaces/IOrbiterProtocal.sol";
import "./Operations.sol";
import "./interfaces/IOrbiterFactory.sol";
import "./Strings.sol";
import "./SafeMath.sol";
import "./Extrator/OrbiterExtrator_L1.sol";

contract OrbiterProtocalV1 is IOrbiterProtocal {
    using SafeMath for uint256;
    address managerAddress;
    mapping(uint256 => address) extractorAddressMap;

    constructor(address _managerAddress) {
        managerAddress = _managerAddress;
        console.log("Deploying a OrbiterProtocalV1 with OrbiterProtocalV1");
    }

    function isSupportChainID(uint256 chainID)
        public
        override
        returns (bool isSupport)
    {
        Operations.chainInfo memory chainInfo = IOrbiterFactory(managerAddress)
            .getChainInfo(chainID);
        if (chainInfo.chainid != 0) {
            return true;
        }
        return false;
    }

    function getDeposit(uint256 chainid, uint256 oneMax)
        external
        override
        returns (uint256 depositAmount)
    {
        require(oneMax > 0, "oneMax must be greater than 0");
        Operations.chainInfo memory chainInfo = IOrbiterFactory(managerAddress)
            .getChainInfo(chainid);
        require(chainInfo.chainid != 0, "must have chaininfo");
        uint256 batchLimit = chainInfo.batchLimit;
        uint256 oneMaxDeposit = getTokenPunish(oneMax);
        uint256 depositAmount = batchLimit * oneMaxDeposit;
        require(
            depositAmount > oneMax,
            "depositAmount must be greater than oneMax"
        );
        return depositAmount;
    }

    function getTokenPunish(uint256 amount)
        public
        view
        override
        returns (uint256 punishAmount)
    {
        uint256 punishNum = 100;
        uint256 punishAmount = amount + (amount * punishNum) / 100;
        require(
            punishAmount > amount,
            "punishAmount must be greater than amount"
        );
        return punishAmount;
    }

    function getETHPunish(uint256 fromChainID)
        external
        view
        override
        returns (uint256 punishETH)
    {}

    function getTxInfo(uint256 chainID, uint256 txIndex)
        public
        override
        returns (Operations.TxInfo memory txinfo)
    {
        address extractorAddress = extractorAddressMap[chainID];
        require(
            extractorAddress != address(0),
            "extractorAddress can not be address(0)"
        );
        IOrbiterExtrator extractor = IOrbiterExtrator(extractorAddress);
        Operations.TxInfo memory txinfo = extractor.getVerifiedTx(txIndex);
        return txinfo;
    }

    function getDisputeTimeTime(uint256 chainID)
        external
        override
        returns (uint256 disputeTime)
    {
        Operations.chainInfo memory chainInfo = IOrbiterFactory(managerAddress)
            .getChainInfo(chainID);
        require(chainInfo.chainid != 0, "must have chaininfo");
        uint256 disputeTime = chainInfo.maxDisputeTime;
        return disputeTime;
    }

    function getStartDealyTime(uint256 chainID)
        external
        view
        override
        returns (uint256)
    {
        uint256 delayTime = 100;
        return delayTime;
    }

    function getStopDealyTime(uint256 chainID)
        external
        view
        override
        returns (uint256)
    {
        uint256 delayTime = 100;
        return delayTime;
    }

    function checkUserChallenge(
        address sender,
        uint256 fromChainID,
        uint256 TxIndex,
        uint256 extIndex,
        uint256 toChainID,
        Operations.LPInfo memory lpinfo,
        Operations.PoolExt memory ext
    ) public override returns (bool isSuccess) {
        Operations.TxInfo memory txinfo = getTxInfo(fromChainID, TxIndex);
        require(txinfo.from == sender, "owner user");
        // require(txinfo.to == makerAddress, 'makerAddress');
        require(
            extIndex <= lpinfo.avalibleTimes.length / 2,
            "extIndex must be legitimate"
        );

        uint256 pText = 9000 + toChainID;
        string memory pTextStr = Strings.toString(pText);
        console.log("pText =", pText);
        console.log("pTextStr =", pTextStr);

        uint256 amount = txinfo.amount;
        string memory amountStr = Strings.toString(amount);
        console.log("amount =", amount);
        console.log("amountStr =", amountStr);

        uint256 amountLength = bytes(amountStr).length;
        string memory amountPText = Strings.getSlice(
            amountLength - 3,
            amountLength,
            amountStr
        );
        console.log("amountLength =", amountLength);
        console.log("amountPText =", amountPText);

        // ========
        console.log(Strings.compare(pTextStr, amountPText));
        if (!Strings.compare(pTextStr, amountPText)) {
            return false;
        }
        // ========
        uint256 txTimeStamp = txinfo.timestamp;
        uint256 startTime = lpinfo.avalibleTimes[2 * extIndex];
        uint256 endTime = 2 * extIndex + 1 < lpinfo.avalibleTimes.length
            ? lpinfo.avalibleTimes[2 * extIndex + 1]
            : 9999999999999;
        console.log("txTimeStamp =", txTimeStamp);
        console.log("startTime =", startTime);
        console.log("endTime =", endTime);

        if (txTimeStamp < startTime || txTimeStamp > endTime) {
            return false;
        }
        console.log("amount =", txinfo.amount);
        console.log("onemin =", ext.onemin);
        console.log("onemax =", ext.onemax);
        if (txinfo.amount < ext.onemin || txinfo.amount > ext.onemax) {
            return false;
        }
        return true;
    }

    function checkMakerChallenge(
        uint256 fromChainID,
        uint256 fromTxIndex,
        uint256 extIndex,
        uint256 toChainID,
        uint256 toTxIndex,
        Operations.LPInfo memory lpinfo,
        Operations.PoolExt memory ext
    ) public override returns (bool isSuccess) {
        Operations.TxInfo memory userTxinfo = getTxInfo(
            fromChainID,
            fromTxIndex
        );
        Operations.TxInfo memory makerTxinfo = getTxInfo(toChainID, toTxIndex);

        require(userTxinfo.from == makerTxinfo.to, "address match1");
        require(userTxinfo.to == makerTxinfo.from, "address match2");
        require(
            extIndex <= lpinfo.avalibleTimes.length / 2,
            "extIndex must be legitimate"
        );

        uint256 userPText = 9000 + toChainID;
        require(
            userTxinfo.nonce >= 0 && userTxinfo.nonce < 9000,
            "nonceInvalid"
        );
        string memory userNonceStr = Strings.toString(userTxinfo.nonce);

        require(
            bytes(userNonceStr).length > 0 && bytes(userNonceStr).length < 5,
            "nonceInvalid"
        );

        string memory zeroStr = "";
        if (bytes(userNonceStr).length < 4) {
            for (
                uint256 index = 0;
                index < 4 - bytes(userNonceStr).length;
                index++
            ) {
                zeroStr = Strings.concatenate(zeroStr, "0");
            }
        }
        string memory makerPtext = Strings.concatenate(zeroStr, userNonceStr);

        string memory makerAmountStr = Strings.toString(makerTxinfo.amount);

        string memory makerAmountPText = Strings.getSlice(
            bytes(makerAmountStr).length - 3,
            bytes(makerAmountStr).length,
            makerAmountStr
        );

        console.log("makerPtext =", makerPtext);
        console.log("makerAmountPText =", makerAmountPText);

        if (Strings.compare(makerPtext, makerAmountPText) == false) {
            return false;
        }

        console.log("makerTxinfo.timestamp", makerTxinfo.timestamp);
        console.log("userTxinfo.timestamp", userTxinfo.timestamp);

        if (makerTxinfo.timestamp - userTxinfo.timestamp > 1200) {
            return false;
        }
        string memory toAmountStr = getToAmountStr(
            userTxinfo.amount.sub(userPText),
            lpinfo,
            ext
        );
        string memory realToAmount = Strings.concatenate(
            Strings.getSlice(
                1,
                bytes(toAmountStr).length - bytes(userNonceStr).length,
                toAmountStr
            ),
            userNonceStr
        );

        console.log("toAmountStr =", toAmountStr);
        console.log("realToAmount =", realToAmount);
        console.log("makerAmountStr =", makerAmountStr);
        if (Strings.compare(realToAmount, makerAmountStr) == false) {
            return false;
        }
        return true;
    }

    function getGasFeeFix(
        uint256 gasFee,
        uint256 digit,
        uint256 precision
    ) private returns (uint256) {
        require(digit < precision, "digit must be less than precision");
        uint256 fixNum = gasFee % (10**(precision - digit));
        uint256 m_amount = fixNum > 0
            ? gasFee.sub(fixNum).add(10**(precision - digit))
            : gasFee;
        return m_amount;
    }

    function getToAmountStr(
        uint256 userAmount,
        Operations.LPInfo memory lpinfo,
        Operations.PoolExt memory ext
    ) private returns (string memory toAmount_fee) {
        console.log("userRealAmount =", userAmount);
        uint256 toAmount_tradingFee = userAmount.sub(
            ext.tradingFee.mul(10**lpinfo.precision)
        );
        console.log("toAmount_tradingFee =", toAmount_tradingFee);
        uint256 gasFee = toAmount_tradingFee.mul(ext.gasFee) / 1000;
        console.log("gasFee =", gasFee);
        uint256 digit = lpinfo.precision == 18 ? 6 : 2;
        console.log("digit =", digit);
        uint256 gasFee_fix = getGasFeeFix(gasFee, digit, lpinfo.precision);
        console.log("gasFee_fix =", gasFee_fix);
        uint256 toAmount_fee = toAmount_tradingFee.sub(gasFee_fix);
        console.log("toAmount_fee =", toAmount_fee);
        string memory toAmountStr = Strings.toString(toAmount_fee);
        return toAmountStr;
    }

    function userChanllengeWithDraw(
        address sender,
        uint256 fromChainID,
        uint256 TxIndex,
        uint256 extIndex,
        uint256 toChainID,
        Operations.LPInfo memory lpinfo
    )
        public
        override
        returns (
            bool isSuccess,
            uint256 eAmount,
            uint256 tAmount
        )
    {
        Operations.TxInfo memory txinfo = getTxInfo(fromChainID, TxIndex);
        require(txinfo.from == sender, "owner user");
        // require(txinfo.to == makerAddress, 'makerAddress');
        require(
            extIndex <= lpinfo.avalibleTimes.length / 2,
            "extIndex must be legitimate"
        );

        uint256 punish = getTokenPunish(txinfo.amount);
        console.log("tokenAmount =", txinfo.amount);
        console.log("punish =", punish);
        uint256 needBackTokenAmount = txinfo.amount.add(punish);
        uint256 needBackEthAmount = getETHGas(fromChainID, toChainID);
        return (true, needBackEthAmount, needBackTokenAmount);
    }

    function getETHGas(uint256 fromChainID, uint256 toChainID)
        public
        override
        returns (uint256 amount)
    {
        return 100;
    }

    function maxWithdrawTime() external view override returns (uint256) {
        return 100;
    }

    /// found chainid from amount
    function fromAmountGetChainId(uint256 amount)
        public
        returns (uint256 chainid)
    {
        chainid = 0;
    }

    function fromAmountCreatToAmount(
        uint256 fromAmount,
        uint256 nonce,
        uint256 gasfee,
        uint256 fee
    ) public returns (uint256 amount) {
        amount = 1;
    }

    function createExtractorContract(uint256 chainID, address tokenAddress)
        external
    {
        require(
            extractorAddressMap[chainID] == address(0),
            "extractorAddressMap have no chainID"
        );
        address depositContract = address(
            new OrbiterExtrator_L1{
                salt: keccak256(abi.encode(msg.sender, chainID))
            }(tokenAddress)
        );
        extractorAddressMap[chainID] = depositContract;
        console.log("extractorAddress =", extractorAddressMap[chainID]);
    }
}
