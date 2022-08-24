// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../library/Operation.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IORMakerDeposit {
    enum lpState {
        ACTION,
        UPDATE,
        PAUSE,
        STOP
    }
    event MakerContract(address indexed maker, address indexed mdc);
    event AddPariChain(address indexed tokenAddress, Operations.pairChainInfo pairChain);
    event AddPariChains(address indexed tokenAddress, Operations.pairChainInfo[] pairChains);
    event LogLpState(bytes32 indexed lpid, lpState indexed state, uint256 time);
    event LogLpInfo(
        bytes32 indexed lpid,
        uint256 indexed sourceChain,
        uint256 indexed destChain,
        Operations.lpInfo lpinfo
    );

    function LPAction(
        Operations.lpInfo memory _lpinfo,
        bytes32[] memory proof,
        bytes32 rootHash
    ) external payable;

    // LPPause
    function LPPause(Operations.lpInfo memory _lpinfo, bytes32 rootHash) external;

    // LPStop
    function LPStop(Operations.lpInfo memory) external;

    // LPUpdate
    function LPUpdate(
        bytes32 leaf,
        bytes32[] calldata proof,
        bool[] calldata proofFlag,
        Operations.lpInfo calldata _lpinfo
    ) external;

    // withDrawAssert()
    function withDrawAssert(uint256, address) external;

    // userChanllenge
    function userChanllenge(
        Operations.lpInfo memory,
        Operations.txInfo memory,
        bytes memory proof
    ) external returns (bool);

    // userWithDraw
    function userWithDraw(Operations.txInfo memory) external returns (bool);

    // makerChanllenger
    function makerChanllenger(
        Operations.txInfo memory,
        Operations.txInfo memory,
        bytes memory
    ) external returns (bool);
}
