// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interface/IORManagerFactory.sol";
import "./ORMakerDeposit.sol";
import "./library/Operation.sol";
import "hardhat/console.sol";

contract ORManagerFactory is IORManagerFactory {
    mapping(address => Operations.pairChainInfo[]) pairChain;
    mapping(uint256 => address) ebcPair;
    mapping(uint256 => Operations.chainInfo) chainInfo;
    address _owner;

    // event AddPariChain(address indexed tokenAddress, Operations.pairChainInfo pairChain);
    // event AddPariChains(address indexed tokenAddress, Operations.pairChainInfo[] pairChains);

    constructor() payable {
        _owner = msg.sender;
    }

    modifier isOwner() {
        require(msg.sender == _owner, "NOT_OWNER");
        _;
    }

    function setPariChainInfo(address tokenAddress, Operations.pairChainInfo[] memory pairChain)
        external
        isOwner
        returns (bool)
    {
        return true;
    }

    function setEBC(address ebcAddress) external isOwner returns (bool) {
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
        // console.log("getPariChainInfo__");
    }

    function getEBC(uint256 ebcid) external returns (address) {
        require(ebcPair[ebcid] != address(0), "EBC_UNINSTALL");
        address ebcAddress = ebcPair[ebcid];
        return ebcAddress;
    }

    function setChainInfoByChainID(
        uint256 chainID,
        bytes memory chainName,
        uint256 batchLimit,
        uint256 maxDisputeTime
    ) external isOwner {
        Operations.chainInfo memory info = Operations.chainInfo(chainID, chainName, batchLimit, maxDisputeTime, true);
        chainInfo[chainID] = info;
    }

    function getChainInfoByChainID(uint256 chainID) external returns (Operations.chainInfo memory) {
        require(chainInfo[chainID].isUsed == true, "MANAGER_CHAININFO_UNINSTALL");
        Operations.chainInfo memory info = chainInfo[chainID];
        return info;
    }

    function getTokenInfoByTokenAddress(address tokenAddress) external returns (Operations.tokenInfo memory) {
        Operations.tokenInfo memory info1 = Operations.tokenInfo(address(0), 18, "eth");
        return info1;
    }

    function getTokenInfoByTokenName(bytes memory tokenName) external view returns (Operations.tokenInfo memory) {
        Operations.tokenInfo memory info1 = Operations.tokenInfo(address(0), 18, "eth");
        return info1;
    }

    function setOwner(address newOwner) public isOwner {
        _owner = newOwner;
    }

    function createMaker() external returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender));
        ORMakerDeposit makerContract = new ORMakerDeposit{salt: salt}(address(this));
        emit MakerMap(msg.sender, address(makerContract));
        return address(makerContract);
    }
}
