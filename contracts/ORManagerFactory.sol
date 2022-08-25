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
    address public spv;

    function getEBCids() external view returns (uint256) {
        return ebcids;
    }

    function setSPV(address spvAddress) external onlyOwner returns (bool) {
        require(spvAddress != address(0) && Address.isContract(spvAddress) == true, "SPV_INVALIDATE");
        spv = spvAddress;
        return true;
    }

    function getSPV() external view returns (address) {
        require(spv != address(0), "SPV_NOT_INSTALL");
        return spv;
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
        uint256 batchLimit,
        uint256 maxDisputeTime,
        address[] memory tokenList
    ) external {
        require(chainList[chainID].isUsed == false, "CHAININFO_INSTALL_ALREADY");
        chainList[chainID] = OperationsLib.chainInfo(chainID, batchLimit, maxDisputeTime, tokenList, true);
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
        address mainAddress
    ) external returns (bool) {
        require(chainList[chainID].tokenList.length != 0, "SETTOKENINFO_UNSUPPORTTOKEN");
        for (uint256 i = 0; i < chainList[chainID].tokenList.length; i++) {
            address supportTokenAddress = chainList[chainID].tokenList[i];
            if (supportTokenAddress == tokenAddress) {
                tokenInfos[chainID][tokenAddress] = OperationsLib.tokenInfo(
                    chainID,
                    tokenAddress,
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
        console.logString("hello");
        console.logBytes32(pairsRoot);
        ORMakerDeposit makerContract = new ORMakerDeposit{salt: salt}(address(this));
        emit MakerMap(msg.sender, address(makerContract));
        return address(makerContract);
    }

    function isSupportChain(uint256 chainID, address token) public view virtual override returns (bool) {
        bool isSupportToken = false;
        for (uint256 i = 0; i < chainList[chainID].tokenList.length; i++) {
            if (chainList[chainID].tokenList[i] == token) {
                isSupportToken = true;
                break;
            }
        }
        console.logString("isSupportChain child");
        return isSupportToken;
    }
}
