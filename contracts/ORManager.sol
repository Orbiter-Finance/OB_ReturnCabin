// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IORManager.sol";
import "./ORMakerDeposit.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Multicall.sol";

contract ORManager is IORManager, Initializable, OwnableUpgradeable, Multicall {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    address public getSPV;
    // internal id => chainId
    mapping(uint256 => uint256) public idChainID;
    // internal id  => ChainInfo
    mapping(uint256 => OperationsLib.ChainInfo) public getChain;
    // tokenId => tokenInfo
    mapping(bytes32 => OperationsLib.TokenInfo) public tokenInfos;
    // pairs
    mapping(bytes32 => OperationsLib.PairStruct) public getPairs;
    // pair id list
    EnumerableSet.Bytes32Set private pairs;
    // ebcAddr list
    EnumerableSet.AddressSet private ebcs;

    function initialize() external initializer {
        __Ownable_init();
    }

    function setSPV(address spv) external onlyOwner {
        require(spv != address(0), "zero-check");
        getSPV = spv;
    }

    function addEBC(address ebc) external onlyOwner {
        require(ebc != address(0), "zero-check");
        // getEBC[++ebcId] = ebc;
        ebcs.add(ebc);
    }

    function revemoEBC(address ebc) external onlyOwner {
        ebcs.remove(ebc);
    }

    function setChainInfo(
        uint256 id,
        uint256 chainId,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        uint256 maxReceiptTime,
        uint256 stopDelayTime,
        uint256 maxBits
    ) external onlyOwner {
        idChainID[chainId] = id;
        getChain[id] = OperationsLib.ChainInfo(
            id,
            chainId,
            batchLimit,
            maxDisputeTime,
            maxReceiptTime,
            stopDelayTime,
            maxBits
        );
        // TODO:
        // emit ChangeChain(chainID, getChain[chainID]);
    }

    function setTokenInfo(
        uint256 chainId,
        uint256 tokenPresion,
        address tokenAddress,
        address mainAddress
    ) external onlyOwner {
        bytes32 tokenId = keccak256(abi.encodePacked(chainId, tokenAddress));
        tokenInfos[tokenId] = OperationsLib.TokenInfo(chainId, uint8(tokenPresion), tokenAddress, mainAddress);
        emit ChangeToken(chainId, tokenAddress, tokenInfos[tokenId]);
    }

    function getTokenInfo(
        uint256 chainID,
        address tokenAddress
    ) external view returns (OperationsLib.TokenInfo memory) {
        require(getChain[chainID].batchLimit > 0, "CHAINID_NOTINSTALL");
        return tokenInfos[keccak256(abi.encodePacked(chainID, tokenAddress))];
    }

    function getPairIds() external view returns (bytes32[] memory) {
        return pairs.values();
    }

    function addPair(OperationsLib.PairStruct calldata pair) external onlyOwner {
        bytes32 pairId = OperationsLib.getPairID(pair);
        pairs.add(pairId);
        getPairs[pairId] = pair;
        emit SupportPair(1, pairId);
    }

    function removePair(bytes32 id) external onlyOwner {
        bool success = pairs.remove(id);
        require(success, "ID does not exist");
        delete getPairs[id];
        emit SupportPair(2, id);
    }

    function isSupportPair(bytes32 pairId) public view returns (bool) {
        return pairs.contains(pairId);
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
            require(pair.ebc != address(0), "EBC does not exist");
            OperationsLib.TokenInfo memory tokenInfo = this.getTokenInfo(pair.sourceChain, pair.sourceToken);
            require(tokenInfo.chainID > 0, "Chain Not Supported");
            uint256 pledgedValue = IORProtocal(pair.ebc).getPledgedAmount(pair.sourceChain, _lp.maxPrice);
            pledgeListData[i] = OperationsLib.CalculatePairPledgeResponse(_lp.pairId, tokenInfo.mainTokenAddress, _lp.maxPrice, pledgedValue);
            unchecked {
                ++i;
            }
        }
        return pledgeListData;
    }
}
