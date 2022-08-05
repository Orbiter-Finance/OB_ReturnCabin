// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interface/IORManagerFactory.sol";
import "./interface/IORMakerDeposit.sol";
import "./library/Operation.sol";
import "hardhat/console.sol";

contract ORManagerFactory is IORManagerFactory {
    mapping(address => Operations.pairChainInfo[]) pairChain;
    mapping(uint256 => address) ebcPair;

    address _owner;

    // event AddPariChain(address indexed tokenAddress, Operations.pairChainInfo pairChain);
    // event AddPariChains(address indexed tokenAddress, Operations.pairChainInfo[] pairChains);

    constructor(address owner) payable {
        _owner = owner;
    }

    function setPariChainInfo(address tokenAddress, Operations.pairChainInfo[] memory pairChain)
        external
        returns (bool)
    {
        return true;
    }

    function setEBC(address ebcAddress) external returns (bool) {
        return true;
    }

    function setChainInfo(
        uint256 chainID,
        bytes memory chainName,
        uint256 batchLimit,
        uint256 maxDisputeTime
    ) external returns (bool) {
        return true;
    }

    function setTokenInfo(
        address tokenAddress,
        bytes memory tokenName,
        uint256 tokenPresion
    ) external returns (bool) {
        return true;
    }

    function getPariChainInfo(address tokenAddress) external view returns (Operations.pairChainInfo[] memory) {
        console.log("getPariChainInfo");
    }

    function getEBC(uint256 ebcid) external returns (address) {
        console.log("getEBC");
    }

    function getChainInfoByChainID(uint256 chainID, bytes memory chainName)
        external
        view
        returns (Operations.chainInfo memory)
    {
        Operations.chainInfo memory info1 = Operations.chainInfo(1, "zksync", 100, 200);
        return info1;
    }

    function getChainInfoByChainName(bytes memory chainName) external view returns (Operations.chainInfo memory) {
        Operations.chainInfo memory info1 = Operations.chainInfo(1, "zksync", 100, 200);
        return info1;
    }

    function getTokenInfoByTokenAddress(address tokenAddress) external returns (Operations.tokenInfo memory) {
        Operations.tokenInfo memory info1 = Operations.tokenInfo(address(0), 18, "eth");
        return info1;
    }

    function getTokenInfoByTokenName(bytes memory tokenName) external view returns (Operations.tokenInfo memory) {
        Operations.tokenInfo memory info1 = Operations.tokenInfo(address(0), 18, "eth");
        return info1;
    }

    function setOwner(address newOwner) external {
        require(_owner == address(0) || _owner == msg.sender);
        _owner = newOwner;
    }

    function createMaker(address makerAddress) external returns (address) {
        // makerContract = address(new IORMakerDeposit{salt: keccak256(abi.encode(msg.sender))}());
        emit MakerMap(msg.sender, makerAddress);
        return makerAddress;
    }
}

// pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
