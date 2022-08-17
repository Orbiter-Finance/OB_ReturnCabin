// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./interface/IORMakerDeposit.sol";
import "./library/Operation.sol";
import "./interface/IORManagerFactory.sol";
import "./interface/IORProtocal.sol";

contract ORMakerDeposit is IORMakerDeposit {
    address _owner;
    address _managerAddress;
    // lpid->lpPairInfo
    mapping(bytes32 => Operations.lpPairInfo) public lpInfo;

    // supportChain->chainDepost
    mapping(uint256 => Operations.chainDeposit[]) public chainDeposit;

    // chanllengeInfos
    mapping(bytes32 => Operations.chanllengeInfo) chanllengeInfos;

    //usedDeposit
    Operations.chainDeposit[] lpDeposit;

    constructor(address managerAddress) payable {
        _owner = msg.sender;
        _managerAddress = managerAddress;
    }

    function LPCreate(Operations.lpInfo memory _lpinfo) external returns (bool) {
        bytes32 lpid = keccak256(
            abi.encodePacked(
                _lpinfo.sourceChain,
                _lpinfo.destChain,
                _lpinfo.sourceTAddress,
                _lpinfo.destTAddress,
                _lpinfo.ebcid
            )
        );
        require(lpInfo[lpid].isUsed == false, "LPCREATE_LPID_USED");
        bytes32 rootHash = keccak256(
            abi.encodePacked(
                _lpinfo.sourceChain,
                _lpinfo.destChain,
                _lpinfo.sourceTAddress,
                _lpinfo.destTAddress,
                _lpinfo.tokenName,
                _lpinfo.tokenPresion,
                _lpinfo.ebcid,
                _lpinfo.minPrice,
                _lpinfo.maxPrice,
                _lpinfo.gasFee,
                _lpinfo.tradingFee
            )
        );
        lpInfo[lpid].LPRootHash = rootHash;
        lpInfo[lpid].isUsed = true;

        Operations.chainInfo memory souceChainInfo = IORManagerFactory(_managerAddress).getChainInfoByChainID(
            _lpinfo.sourceChain
        );
        uint256 depositAmount = souceChainInfo.batchLimit * _lpinfo.maxPrice;
        lpInfo[lpid].shouldUseAmount = depositAmount;

        // emit LogLpState(lpid, lpInfo[lpid].startTime, lpState.CREAT);
        // emit LogLpInfo(
        //     lpid,
        //     _lpinfo.sourceChain,
        //     _lpinfo.destChain,
        //     _lpinfo.sourceTAddress,
        //     _lpinfo.destTAddress,
        //     _lpinfo.tokenPresion,
        //     _lpinfo.ebcid,
        //     _lpinfo.minPrice,
        //     _lpinfo.maxPrice,
        //     _lpinfo.gasFee,
        //     _lpinfo.tradingFee,
        //     _lpinfo.tokenName
        // );
    }

    // LPAction
    function LPAction(bytes32 lpid) external returns (bool) {
        require(lpInfo[lpid].isUsed == true, "LPACTION_LPID_UNUSED");
        require(lpInfo[lpid].startTime == 0, "LPACTION_LPID_UNSTOPED");

        lpInfo[lpid].startTime == block.timestamp;

        //TODO

        emit LogLpState(lpid, lpInfo[lpid].startTime, lpState.ACTION);
        return true;
    }

    // LPPause
    function LPPause(bytes32 lpid) external returns (bool) {
        // console.log(lpid);
        return true;
    }

    // LPStop
    function LPStop(bytes32 lpid) external returns (bool) {
        // console.log(lpid);
        return true;
    }

    // LPUpdate
    function LPUpdate(
        bytes32 lpid,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 gasFee,
        uint256 tradingFee
    ) external returns (bool) {
        // console.log(lpid, minPrice, maxPrice, gasFee + tradingFee);
        return true;
    }

    // withDrawAssert()
    function withDrawAssert(uint256 amount, bytes memory token) external returns (bool) {
        console.log(amount);
        return true;
    }

    // userChanllenge
    function userChanllenge(
        Operations.lpInfo memory _lpinfo,
        Operations.txInfo memory _txinfo,
        bytes memory _proof
    ) external returns (bool) {
        //TODO
        //1. txinfo is already spv
        //2. txinfo unChanllenge
        bytes32 chanllengeID = keccak256(
            abi.encodePacked(
                _txinfo.sourceAddress,
                _txinfo.destAddress,
                _txinfo.tokenName,
                _txinfo.tokenAmount,
                _txinfo.nonce,
                _txinfo.gas
            )
        );
        require(chanllengeInfos[chanllengeID].chanllengeState == 0, "USERCHANLLENGE_USED");
        //3. get response changellengeinfo
        bytes32 responseInfoHash = "000000000";
        chanllengeInfos[chanllengeID].responseTxinfo = responseInfoHash;
        chanllengeInfos[chanllengeID].chanllengeState = 1;
        chanllengeInfos[chanllengeID].startTime = block.timestamp;
        return true;
    }

    // userWithDraw
    function userWithDraw(Operations.txInfo memory userInfo) external returns (bool) {
        console.log(userInfo.sourceAddress);
        return true;
    }

    // makerChanllenger
    function makerChanllenger(
        Operations.txInfo memory _userTx,
        Operations.txInfo memory _makerTx,
        bytes memory proof
    ) external returns (bool) {
        bytes32 chanllengeID = keccak256(
            abi.encodePacked(
                _userTx.sourceAddress,
                _userTx.destAddress,
                _userTx.tokenName,
                _userTx.tokenAmount,
                _userTx.nonce,
                _userTx.gas
            )
        );
        require(chanllengeInfos[chanllengeID].chanllengeState == 1, "MAKERCHANLLENGE_WATTINGFORANSWER");
        bytes32 makerResponse = "000000000";
        require(chanllengeInfos[chanllengeID].responseTxinfo == makerResponse, "MAKERCHANLLENGE_UNMATCH");
        chanllengeInfos[chanllengeID].chanllengeState = 2;
        console.logBytes(proof);
        return true;
    }
}

// pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
