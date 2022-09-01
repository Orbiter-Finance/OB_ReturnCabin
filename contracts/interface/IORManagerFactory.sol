// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";

interface IORManagerFactory {
    event MakerMap(address indexed makerAddress, address indexed contractAddress);
    enum PairEventType {
        CREATE,
        DELETE
    }
    event PairLogEvent(PairEventType index, OperationsLib.pairChainInfo[]);

    function setSPV(address spvAddress) external returns (bool);

    function getSPV() external view returns (address);

    function setEBC(address ebcAddress) external returns (bool);

    function getEBC(uint256 ebcid) external returns (address);

    function updateEBC(uint256 ebcid, address ebcAddress) external;

    function setChainInfo(
        uint256,
        uint256,
        uint256,
        address[] memory
    ) external;

    function getChainInfoByChainID(uint256 chainID) external returns (OperationsLib.chainInfo memory);

    function setTokenInfo(
        uint256,
        address,
        uint256,
        address
    ) external returns (bool);

    function getTokenInfo(uint256, address) external view returns (OperationsLib.tokenInfo memory);

    function createMaker() external returns (address);

    function createPair(
        OperationsLib.pairChainInfo[] calldata pairs,
        bytes32 rootHash,
        bytes32[] calldata proof,
        bool[] calldata proofFlags
    ) external;

    function deletePair(
        OperationsLib.pairChainInfo[] calldata pairs,
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 rootHash
    ) external;

    function isSupportPair(bytes32 pair, bytes32[] memory proof) external view returns (bool);

    function isSupportPair(OperationsLib.pairChainInfo calldata pair, bytes32[] calldata proof)
        external
        view
        returns (bool);
}
