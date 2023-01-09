// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IORManager.sol";
import "./ORMakerDeposit.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ORManager is IORManager, Initializable, OwnableUpgradeable {
    mapping(uint256 => OperationsLib.chainInfo) public getChain;
    // chainId => tokenAddress
    mapping(uint256 => mapping(address => OperationsLib.tokenInfo)) public tokenInfos;
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

    function setChainInfo(
        uint256 chainID,
        uint256 batchLimit,
        uint256 maxDisputeTime,
        uint256 maxReceiptTime,
        uint256 stopDelayTime,
        address[] memory tokenList
    ) external onlyOwner {
        getChain[uint16(chainID)] = OperationsLib.chainInfo(
            uint16(chainID),
            batchLimit,
            maxDisputeTime,
            maxReceiptTime,
            stopDelayTime,
            tokenList,
            true
        );
        emit ChangeChain(chainID, getChain[chainID]);
    }

    function setTokenInfo(
        uint256 chainID,
        uint256 tokenPresion,
        address tokenAddress,
        address mainAddress
    ) external onlyOwner {
        require(getChain[chainID].tokenList.length != 0, "SETTOKENINFO_UNSUPPORTTOKEN");
        for (uint256 i = 0; i < getChain[chainID].tokenList.length; ) {
            address supportTokenAddress = getChain[chainID].tokenList[i];
            if (supportTokenAddress == tokenAddress) {
                tokenInfos[chainID][tokenAddress] = OperationsLib.tokenInfo(
                    uint16(chainID),
                    tokenAddress,
                    uint8(tokenPresion),
                    mainAddress
                );
            }
            emit ChangeToken(chainID, tokenAddress, tokenInfos[chainID][tokenAddress]);
            unchecked {
                ++i;
            }
        }
    }

    function getTokenInfo(uint256 chainID, address tokenAddress)
        external
        view
        returns (OperationsLib.tokenInfo memory)
    {
        require(getChain[chainID].isUsed == true, "CHAINID_NOTINSTALL");
        require(getChain[chainID].tokenList.length != 0, "CHAINID_UNSUPPORTTOKEN");
        for (uint256 i = 0; i < getChain[chainID].tokenList.length; ) {
            address supportAddress = getChain[chainID].tokenList[i];
            if (supportAddress == tokenAddress) {
                return tokenInfos[chainID][tokenAddress];
            }
            unchecked {
                ++i;
            }
        }
        revert("UNSUPPORTTOKEN");
    }

    function isSupportChain(uint256 chainID, address token) public view returns (bool) {
        bool isSupportToken = false;
        for (uint256 i = 0; i < getChain[chainID].tokenList.length; ) {
            if (getChain[chainID].tokenList[i] == token) {
                isSupportToken = true;
                break;
            }
            unchecked {
                ++i;
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
        bytes32 rootHash,
        bool[] calldata proofFlags
    ) external {
        bool isSupport = pairMultiProofVerifyCalldata(pairs, pairsRoot, proof, proofFlags);
        require(isSupport, "Hash Inconsistent");
        pairsRoot = rootHash;
        emit PairLogEvent(PairEventType.DELETE, pairs);
    }

    function isSupportPair(bytes32 pair, bytes32[] calldata proof) public view returns (bool) {
        return MerkleProof.verifyCalldata(proof, pairsRoot, pair);
    }

    function pairObjectToHash(OperationsLib.pairChainInfo[] calldata pairs) internal pure returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](pairs.length);
        for (uint256 i = 0; i < pairs.length; ) {
            leaves[i] = OperationsLib.getPairID(pairs[i]);
            unchecked {
                ++i;
            }
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
        external
        view
        returns (address pledgedToken, OperationsLib.lpPledgeCalculate[] memory)
    {
        OperationsLib.tokenInfo memory depositToken = this.getTokenInfo(_lpinfos[0].fromChain, _lpinfos[0].fromToken);
        uint256 maxNum = 0;
        pledgedToken = depositToken.mainTokenAddress;
        OperationsLib.lpPledgeCalculate[] memory pledgeListData = new OperationsLib.lpPledgeCalculate[](
            _lpinfos.length
        );
        for (uint256 i = 0; i < _lpinfos.length; ) {
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
            for (uint256 j = 0; j < pledgeListData.length; ) {
                if (pledgeListData[j].chainId == _lpinfo.fromChain) {
                    isExists = true;
                    if (baseValue + additiveValue > pledgeListData[j].pledgeValue) {
                        pledgeListData[j].pledgeValue = baseValue + additiveValue;
                    }
                    break;
                }
                unchecked {
                    ++j;
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
            unchecked {
                ++i;
            }
        }

        return (pledgedToken, pledgeListData);
    }
}
