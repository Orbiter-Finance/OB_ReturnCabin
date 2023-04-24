// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IORManager.sol";
import "./interface/IORProtocal.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Multicall.sol";

contract ORManager is IORManager, Initializable, OwnableUpgradeable, Multicall {
    uint public ebcId;
    // chain id  => ChainInfo
    mapping(uint => OperationsLib.ChainInfo) public getChain;
    // (chainId + token addr) => tokenInfo
    mapping(bytes32 => OperationsLib.TokenInfo) public getChainToken;
    // pairId => pairInfo
    mapping(bytes32 => OperationsLib.PairStruct) public getPairs;
    // ebc
    // ebcId => ebcAddress
    mapping(uint => address) public getEBCAddress;
    // ebcAddress => ebcId
    mapping(address => uint) public getEBC;
    // chainId => spvAddress
    mapping(uint => address) public getSPV;

    function initialize() external initializer {
        __Ownable_init();
    }

    function registerSPV(uint256 chain, address addr) external onlyOwner {
        require(addr != address(0), "zero-check");
        getSPV[chain] = addr;
        emit RegisterSPV(chain, addr);
    }

    function registerEBC(address addr) external onlyOwner {
        require(addr != address(0), "zero-check");
        require(getEBC[addr] == 0, "exist-check");
        ++ebcId;
        getEBCAddress[ebcId] = addr;
        getEBC[addr] = ebcId;
        emit RegisterEBC(ebcId, addr);
    }

    function registerPair(OperationsLib.PairStruct calldata pair) external onlyOwner {
        bytes32 pairId = OperationsLib.getPairID(pair);
        getPairs[pairId] = pair;
        emit RegisterPair(pairId);
    }

    function deletePair(bytes32 id) external onlyOwner {
        require(isExistsPair(id), "ID does not exist");
        delete getPairs[id];
        emit DeletePair(id);
    }

    function isExistsPair(bytes32 id) public view returns (bool) {
        return getPairs[id].ebcId != 0;
    }

    function registerChain(
        uint256 id,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        uint256 maxReceiptTime,
        uint256 stopDelayTime,
        uint256 maxBits
    ) external onlyOwner {
        getChain[id] = OperationsLib.ChainInfo(id, batchLimit, maxDisputeTime, maxReceiptTime, stopDelayTime, maxBits);
        emit RegisterChain(id);
    }

    function registerToken(
        uint256 chainId,
        uint256 tokenPresion,
        address tokenAddress,
        address mainAddress
    ) external onlyOwner {
        bytes32 tokenId = keccak256(abi.encodePacked(chainId, tokenAddress));
        getChainToken[tokenId] = OperationsLib.TokenInfo(chainId, uint8(tokenPresion), tokenAddress, mainAddress);
        emit RegisterToken(chainId, tokenAddress);
    }

    function getTokenInfo(
        uint256 chainID,
        address tokenAddress
    ) external view returns (OperationsLib.TokenInfo memory) {
        require(getChain[chainID].batchLimit > 0, "CHAINID_NOTINSTALL");
        return getChainToken[keccak256(abi.encodePacked(chainID, tokenAddress))];
    }

    function calculatePairPledgeAmount(
        OperationsLib.LPActionStruct[] calldata _lps
    ) external view returns (OperationsLib.CalculatePairPledgeResponse[] memory) {
        OperationsLib.CalculatePairPledgeResponse[]
            memory pledgeListData = new OperationsLib.CalculatePairPledgeResponse[](_lps.length);
        for (uint256 i = 0; i < _lps.length; ) {
            OperationsLib.LPActionStruct calldata _lp = _lps[i];
            require(_lp.minPrice < _lp.maxPrice, "Illegal minPrice maxPrice value");
            OperationsLib.PairStruct memory pair = getPairs[_lp.pairId];

            require(pair.sourceChain != 0, "ID does not exist");
            require(pair.destChain != 0, "ChainID does not exist");
            require(pair.ebcId != 0, "EBC does not exist");
            //
            
            address ebcAddress = getEBCAddress[pair.ebcId];
            OperationsLib.TokenInfo memory tokenInfo = this.getTokenInfo(pair.sourceChain, pair.sourceToken);
            require(tokenInfo.chainID > 0, "Chain Not Supported");
            uint256 pledgedValue = IORProtocal(ebcAddress).getPledgedAmount(pair.sourceChain, _lp.maxPrice);
            pledgeListData[i] = OperationsLib.CalculatePairPledgeResponse(
                _lp.pairId,
                tokenInfo.mainTokenAddress,
                _lp.maxPrice,
                pledgedValue
            );
            unchecked {
                ++i;
            }
        }
        return pledgeListData;
    }
}
