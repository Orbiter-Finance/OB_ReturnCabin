// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interface/IORMakerDeposit.sol";
import "./library/Operation.sol";
import "hardhat/console.sol";

contract ORMakerDeposit is IORMakerDeposit {
    address _owner;

    // event AddPariChain(address indexed tokenAddress, Operations.pairChainInfo pairChain);
    // event AddPariChains(address indexed tokenAddress, Operations.pairChainInfo[] pairChains);

    constructor(address owner) payable {
        _owner = owner;
    }

    function LPCreate(Operations.lpInfo memory) external returns (bool) {
        return true;
    }

    // LPAction
    function LPAction(uint256 lpid) external returns (bool) {
        console.log(lpid);
        return true;
    }

    // LPPause
    function LPPause(uint256 lpid) external returns (bool) {
        console.log(lpid);
        return true;
    }

    // LPStop
    function LPStop(uint256 lpid) external returns (bool) {
        console.log(lpid);
        return true;
    }

    // LPUpdate
    function LPUpdate(
        uint256 lpid,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 gasFee,
        uint256 tradingFee
    ) external returns (bool) {
        console.log(lpid, minPrice, maxPrice, gasFee + tradingFee);
        return true;
    }

    // withDrawAssert()
    function withDrawAssert(uint256 amount, bytes memory token) external returns (bool) {
        console.log(amount);
        return true;
    }

    // userChanllenge
    function userChanllenge(
        Operations.lpInfo memory,
        Operations.txInfo memory,
        bytes memory proof
    ) external returns (bool) {
        console.logBytes(proof);
        return true;
    }

    // userWithDraw
    function userWithDraw(Operations.txInfo memory userInfo) external returns (bool) {
        console.log(userInfo.sourceAddress);
        return true;
    }

    // makerChanllenger
    function makerChanllenger(
        Operations.txInfo memory,
        Operations.txInfo memory,
        bytes memory proof
    ) external returns (bool) {
        console.logBytes(proof);
        return true;
    }
}

// pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
