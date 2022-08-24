// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interface/IORManagerFactory.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ORMakerDeposit.sol";
import "./ORPairManager.sol";

contract ORManagerFactory is IORManagerFactory, ORPairManager, Ownable {
    mapping(uint256 => address) ebcPair;
    mapping(uint256 => OperationsLib.chainInfo) public chainList;
    mapping(uint256 => mapping(address => OperationsLib.tokenInfo)) public tokenInfos;
    uint256 ebcids;

    function getEBCids() external view returns (uint256) {
        return ebcids;
    }

    function setEBC(address ebcAddress) external onlyOwner returns (bool) {
        // require(Address.isContract(ebcAddress) == true, "SETEBC_INVALIDATEADDRESS");
        ebcPair[ebcids++] = ebcAddress;
        return true;
    }

    function updateEBC(uint256 ebcid, address ebcAddress) external onlyOwner {
        require(ebcPair[ebcid] != address(0), "UPDATEEBC_ERROR");
        ebcPair[ebcid] = ebcAddress;
    }

    function getEBC(uint256 ebcid) external view returns (address) {
        require(ebcPair[ebcid] != address(0), "EBC_UNINSTALL");
        address ebcAddress = ebcPair[ebcid];
        return ebcAddress;
    }

    function setChainInfo(
        uint256 chainID,
        bytes memory chainName,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        address[] memory tokenList
    ) external {
        require(chainList[chainID].isUsed == false, "CHAININFO_INSTALL_ALREADY");
        chainList[chainID] = OperationsLib.chainInfo(chainID, chainName, batchLimit, maxDisputeTime, tokenList, true);
    }

    function getChainInfoByChainID(uint256 chainID) public view returns (OperationsLib.chainInfo memory) {
        require(chainList[chainID].isUsed == true, "MANAGER_CHAININFO_UNINSTALL");
        OperationsLib.chainInfo memory info = chainList[chainID];
        return info;
    }

    // TODO
    function setTokenInfo(
        uint256 chainID,
        address tokenAddress,
        uint256 tokenPresion,
        bytes memory tokenName,
        address mainAddress
    ) external returns (bool) {
        require(chainList[chainID].tokenList.length != 0, "SETTOKENINFO_UNSUPPORTTOKEN");
        for (uint256 i = 0; i < chainList[chainID].tokenList.length; i++) {
            address supportTokenAddress = chainList[chainID].tokenList[i];
            if (supportTokenAddress == tokenAddress) {
                tokenInfos[chainID][tokenAddress] = OperationsLib.tokenInfo(
                    chainID,
                    tokenAddress,
                    tokenName,
                    tokenPresion,
                    mainAddress
                );
            }
        }
        return false;
    }

    function getTokenInfo(uint256 chainID, address tokenAddress)
        external
        view
        returns (OperationsLib.tokenInfo memory)
    {
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

    function createMaker() external returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender));
        ORMakerDeposit makerContract = new ORMakerDeposit{salt: salt}(address(this));
        emit MakerMap(msg.sender, address(makerContract));
        return address(makerContract);
    }
}
