// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interface/IORManagerFactory.sol";
import "./ORMakerDeposit.sol";
import "./library/Operation.sol";
import "hardhat/console.sol";
import "./PairManager.sol";

contract ORManagerFactory is IORManagerFactory, PairManager, Ownable {
    mapping(uint256 => address) ebcPair;
    mapping(uint256 => Operations.chainInfo) chainList;
    mapping(uint256 => mapping(address => Operations.tokenInfo)) tokenInfos;
    uint256 ebcids;

    // event AddPariChain(address indexed tokenAddress, Operations.pairChainInfo pairChain);
    // event AddPariChains(address indexed tokenAddress, Operations.pairChainInfo[] pairChains);

    constructor() payable {}

    function initPariChainInfo(Operations.pairChainInfo[] memory pairChain) external onlyOwner returns (bool) {
        // TODO
        // init pairChainRootHash
        return true;
    }

    function addPariChainInfo(
        Operations.pairChainInfo[] memory pairChain,
        bytes32 proof,
        bool[] memory proofFlag
    ) external onlyOwner returns (bool) {
        // TODO
        // init pairChainRootHash
        return true;
    }

    function updatePariChainInfo(
        Operations.pairChainInfo[] memory oldPairChain,
        Operations.pairChainInfo[] memory newPairChain,
        bytes32 proof,
        bool[] memory proofFlag
    ) external onlyOwner returns (bool) {
        // TODO
        // init pairChainRootHash
        return true;
    }

    function deletePariChainInfo(
        Operations.pairChainInfo[] memory pairChain,
        bytes32 proof,
        bool[] memory proofFlag
    ) external onlyOwner returns (bool) {
        // TODO
        // init pairChainRootHash
        return true;
    }

    function setEBC(address ebcAddress) external onlyOwner returns (bool) {
        ebcPair[ebcids++] = ebcAddress;
    }

    function updateEBC(uint256 ebcid, address ebcAddress) external onlyOwner {
        require(ebcPair[ebcid] != address(0), "UPDATEEBC_ERROR");
        ebcPair[ebcid] = ebcAddress;
    }

    function setChainInfo(
        uint256 chainID,
        bytes memory chainName,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        // Operations.tokenInfo[] memory tokenList
        address[] memory tokenList
    ) external {
        require(chainList[chainID].isUsed == false, "CHAININFO_INSTALL_ALREADY");
        chainList[chainID] = Operations.chainInfo(chainID, chainName, batchLimit, maxDisputeTime, tokenList, true);
    }

    function getTokenInfo(uint256 chainID, address tokenAddress) external view returns (Operations.tokenInfo memory) {
        require(tokenAddress != address(0), "GETTOKENINFO_ERROR");
        require(chainList[chainID].isUsed == true, "CHAINID_NOTINSTALL");
        require(chainList[chainID].tokenList.length != 0, "CHAINID_UNSUPPORTTOKEN");
        for (uint256 i = 0; i < chainList[chainID].tokenList.length; i++) {
            address supportAddress = chainList[chainID].tokenList[i];
            if (supportAddress == tokenAddress) {
                return tokenInfos[chainID][tokenAddress];
            }
        }
        // TODO  error
    }

    // TODO
    function setTokenInfo(
        uint256 chainID,
        address tokenAddress,
        uint256 tokenPresion,
        bytes8 tokenName,
        address mainAddress
    ) external returns (bool) {
        require(chainList[chainID].tokenList.length != 0, "SETTOKENINFO_UNSUPPORTTOKEN");
        for (uint256 i = 0; i <= chainList[chainID].tokenList.length; i++) {
            address supportTokenAddress = chainList[chainID].tokenList[i];
            if (supportTokenAddress == tokenAddress) {
                tokenInfos[chainID][tokenAddress] = Operations.tokenInfo(
                    tokenAddress,
                    tokenName,
                    tokenPresion,
                    mainAddress
                );
            }
        }
        return false;
    }

    function getEBC(uint256 ebcid) external view returns (address) {
        require(ebcPair[ebcid] != address(0), "EBC_UNINSTALL");
        address ebcAddress = ebcPair[ebcid];
        return ebcAddress;
    }

    function getChainInfoByChainID(uint256 chainID) public view returns (Operations.chainInfo memory) {
        require(chainList[chainID].isUsed == true, "MANAGER_CHAININFO_UNINSTALL");
        Operations.chainInfo memory info = chainList[chainID];
        return info;
    }

    function createMaker() external returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender));
        ORMakerDeposit makerContract = new ORMakerDeposit{salt: salt}(address(this));
        emit MakerMap(msg.sender, address(makerContract));
        return address(makerContract);
    }
}
