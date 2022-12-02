// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IORManager.sol";
import "./ORMakerDeposit.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ORManager is IORManager, Initializable, OwnableUpgradeable {
    mapping(uint16 => OperationsLib.chainInfo) public getChain;
    // mapping(uint256 => EnumerableSet.AddressSet) public getChain;
    // mapping(uint256 => EnumerableSet.UintSet) tokens;
    // chainId => tokenAddress
    mapping(uint16 => mapping(address => OperationsLib.tokenInfo)) public tokenInfos;
    uint256 public ebcId;
    mapping(uint256 => address) public getEBC;
    bytes32 public pairsRoot;
    address public getSPV;

    function initialize() external initializer {
        __Ownable_init();
    }

    function setSPV(address spv) external onlyOwner {
        require(spv != address(0), "zero-check");
        getSPV = spv;
    }

    function setEBC(address ebc) external onlyOwner {
        require(ebc != address(0), "zero-check");
        getEBC[++ebcId] = ebc;
    }

    function updateEBC(uint256 id, address addr) external onlyOwner {
        require(getEBC[id] != address(0), "zero-check");
        getEBC[id] = addr;
    }

    function setChainInfos(OperationsLib.chainInfo[] calldata chains) external onlyOwner {
        for (uint256 i = 0; i < chains.length; i++) {
            OperationsLib.chainInfo calldata chain = chains[i];
            getChain[chain.chainid] = OperationsLib.chainInfo(
                chain.chainid,
                chain.batchLimit,
                chain.maxDisputeTime,
                chain.maxReceiptTime,
                chain.stopDelayTime,
                chain.tokenList,
                true
            );
            emit ChangeChain(chain.chainid, getChain[chain.chainid]);
        }
    }

    function setChainInfo(
        uint16 chainID,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        uint256 maxReceiptTime,
        uint256 stopDelayTime,
        address[] memory tokenList
    ) external onlyOwner {
        getChain[chainID] = OperationsLib.chainInfo(
            chainID,
            batchLimit,
            maxDisputeTime,
            maxReceiptTime,
            stopDelayTime,
            tokenList,
            true
        );
        emit ChangeChain(chainID, getChain[chainID]);
    }

    function setTokenInfos(OperationsLib.tokenInfo[] calldata tokens) external onlyOwner {
        for (uint256 k = 0; k < tokens.length; k++) {
            uint16 chainID = tokens[k].chainID;
            uint8 decimals = tokens[k].decimals;
            address tokenAddress = tokens[k].tokenAddress;
            address mainAddress = tokens[k].mainTokenAddress;
            require(getChain[chainID].tokenList.length != 0, "SETTOKENINFO_UNSUPPORTTOKEN");
            for (uint256 i = 0; i < getChain[chainID].tokenList.length; i++) {
                address supportTokenAddress = getChain[chainID].tokenList[i];
                if (supportTokenAddress == tokenAddress) {
                    tokenInfos[chainID][tokenAddress] = OperationsLib.tokenInfo(
                        chainID,
                        tokenAddress,
                        decimals,
                        mainAddress
                    );
                }
                emit ChangeToken(chainID, tokenAddress, tokenInfos[chainID][tokenAddress]);
            }
        }
    }

    function setTokenInfo(
        uint16 chainID,
        address tokenAddress,
        uint8 tokenPresion,
        address mainAddress
    ) external onlyOwner {
        require(getChain[chainID].tokenList.length != 0, "SETTOKENINFO_UNSUPPORTTOKEN");
        for (uint256 i = 0; i < getChain[chainID].tokenList.length; i++) {
            address supportTokenAddress = getChain[chainID].tokenList[i];
            if (supportTokenAddress == tokenAddress) {
                tokenInfos[chainID][tokenAddress] = OperationsLib.tokenInfo(
                    chainID,
                    tokenAddress,
                    tokenPresion,
                    mainAddress
                );
            }
            emit ChangeToken(chainID, tokenAddress, tokenInfos[chainID][tokenAddress]);
        }
    }

    function getTokenInfo(uint16 chainID, address tokenAddress)
        external
        view
        returns (OperationsLib.tokenInfo memory)
    {
        require(getChain[chainID].isUsed == true, "CHAINID_NOTINSTALL");
        require(getChain[chainID].tokenList.length != 0, "CHAINID_UNSUPPORTTOKEN");
        for (uint256 i = 0; i < getChain[chainID].tokenList.length; i++) {
            address supportAddress = getChain[chainID].tokenList[i];
            if (supportAddress == tokenAddress) {
                return tokenInfos[chainID][tokenAddress];
            }
        }
        revert("UNSUPPORTTOKEN");
    }

    function isSupportChain(uint16 chainID, address token) public view returns (bool) {
        bool isSupportToken = false;
        for (uint256 i = 0; i < getChain[chainID].tokenList.length; i++) {
            if (getChain[chainID].tokenList[i] == token) {
                isSupportToken = true;
                break;
            }
        }
        return isSupportToken;
    }

    function createPair(
        OperationsLib.pairChainInfo[] calldata pairs,
        bytes32 rootHash,
        bytes32[] calldata proof,
        bool[] calldata proofFlags
    ) external {
        // is support chain
        bool isSupport = pairMultiProofVerifyCalldata(pairs, rootHash, proof, proofFlags);
        require(isSupport, "Hash Inconsistent");
        pairsRoot = rootHash;
        emit PairLogEvent(PairEventType.CREATE, pairs);
    }

    function deletePair(
        OperationsLib.pairChainInfo[] calldata pairs,
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 rootHash
    ) external {
        bool isSupport = pairMultiProofVerifyCalldata(pairs, pairsRoot, proof, proofFlags);
        require(isSupport, "Hash Inconsistent");
        pairsRoot = rootHash;
        emit PairLogEvent(PairEventType.DELETE, pairs);
    }

    function isSupportPair(bytes32 pair, bytes32[] calldata proof) public view returns (bool) {
        return MerkleProof.verifyCalldata(proof, pairsRoot, pair);
    }

    function isSupportPair(OperationsLib.pairChainInfo calldata pair, bytes32[] calldata proof)
        public
        view
        returns (bool)
    {
        bytes32 pairId = OperationsLib.getPairID(pair);
        return isSupportPair(pairId, proof);
    }

    function pairObjectToHash(OperationsLib.pairChainInfo[] calldata pairs) internal pure returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](pairs.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            leaves[i] = OperationsLib.getPairID(pairs[i]);
        }
        return leaves;
    }

    function pairMultiProofVerifyCalldata(
        OperationsLib.pairChainInfo[] calldata pairs,
        bytes32 root,
        bytes32[] calldata proof,
        bool[] calldata proofFlags
    ) internal pure returns (bool isSupport) {
        bytes32[] memory leaves = pairObjectToHash(pairs);
        return MerkleProof.multiProofVerifyCalldata(proof, proofFlags, root, leaves);
    }

    function calcLpPledgeAmount(OperationsLib.calcLpNeedPledgeAmountParams[] calldata _lpinfos)
        public
        view
        returns (address pledgedToken, OperationsLib.lpPledgeCalculate[] memory)
    {
        OperationsLib.tokenInfo memory depositToken = this.getTokenInfo(_lpinfos[0].fromChain, _lpinfos[0].fromToken);
        uint16 maxNum = 0;
        pledgedToken = depositToken.mainTokenAddress;
        OperationsLib.lpPledgeCalculate[] memory pledgeListData = new OperationsLib.lpPledgeCalculate[](
            _lpinfos.length
        );
        for (uint16 i = 0; i < _lpinfos.length; i++) {
            OperationsLib.calcLpNeedPledgeAmountParams memory _lpinfo = _lpinfos[i];
            depositToken = this.getTokenInfo(_lpinfo.fromChain, _lpinfo.fromToken);
            require(depositToken.mainTokenAddress == pledgedToken, "pledge is not supported");
            address ebcAddress = getEBC[_lpinfo.ebcId];
            OperationsLib.chainInfo memory souceChainInfo = getChain[_lpinfo.fromChain];
            require(souceChainInfo.chainid != 0, "chain not exist");
            (uint256 baseValue, uint256 additiveValue) = IORProtocal(ebcAddress).getPledgeAmount(
                souceChainInfo.batchLimit,
                _lpinfo.maxPrice
            );
            bool isExists = false;
            for (uint16 j = 0; j < pledgeListData.length; j++) {
                if (pledgeListData[j].chainId == _lpinfo.fromChain) {
                    isExists = true;
                    if (baseValue + additiveValue > pledgeListData[j].pledgeValue) {
                        pledgeListData[j].pledgeValue = baseValue + additiveValue;
                    }
                    break;
                }
            }
            if (!isExists) {
                pledgeListData[maxNum] = OperationsLib.lpPledgeCalculate(
                    _lpinfo.fromChain,
                    baseValue,
                    additiveValue,
                    0,
                    baseValue + additiveValue
                );
                maxNum++;
            }
        }
        // pledgeListData.length = 5;
        // OperationsLib.lpPledgeCalculate[] memory pledgeListData = new OperationsLib.lpPledgeCalculate[](maxNum);
        // for (uint256 i = 0; i < pledgeData.length; i++) {
        //     if (pledgeData[i].chainId != 0) {
        //         pledgeListData[i] = pledgeData[i];
        //         // if (pledgeListData[i].pledgeValue > pledgeListData[i].pledged) {
        //         //     totalPledgeValue += pledgeListData[i].pledgeValue - pledgeListData[i].pledged;
        //         // }
        //     }
        // }
        return (pledgedToken, pledgeListData);
    }
}
