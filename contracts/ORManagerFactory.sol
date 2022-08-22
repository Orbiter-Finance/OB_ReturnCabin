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
    uint256 ebcids;

    constructor() payable {}

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
        Operations.tokenInfo[] memory tokenList
    ) external {
        require(chainList[chainID].isUsed == false, "CHAININFO_INSTALL_ALREADY");
        // chainList[chainID] = Operations.chainInfo(chainID, chainName, batchLimit, maxDisputeTime, tokenList, true);
    }

    function getTokenInfo(
        uint256 chainID,
        address tokenAddress,
        bytes8 tokenName
    ) external view returns (Operations.tokenInfo memory) {
        require(tokenAddress != address(0) || tokenName.length != 0, "GETTOKENINFO_ERROR");
        require(chainList[chainID].isUsed == true, "CHAINID_NOTINSTALL");
        Operations.tokenInfo[] memory tokenList = chainList[chainID].tokenList;
        require(tokenList.length != 0, "CHAINID_UNSUPPORTTOKEN");
        for (uint256 i = 0; i <= tokenList.length; i++) {
            Operations.tokenInfo memory tInfo = tokenList[i];
            if (tInfo.tokenAddress == tokenAddress || tInfo.tokenName == tokenName) {
                return tInfo;
            }
        }
        // TODO  error
    }

    // TODO
    function setTokenInfo(
        uint256 chainID,
        address tokenAddress,
        uint256 tokenPresion
    ) external returns (bool) {
        require(chainList[chainID].tokenList.length != 0, "SETTOKENINFO_UNSUPPORTTOKEN");
        for (uint256 i = 0; i <= chainList[chainID].tokenList.length; i++) {
            Operations.tokenInfo memory tInfo = chainList[chainID].tokenList[i];
            if (tInfo.tokenAddress == tokenAddress) {
                tInfo.tokenPresion = tokenPresion;
                return true;
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
