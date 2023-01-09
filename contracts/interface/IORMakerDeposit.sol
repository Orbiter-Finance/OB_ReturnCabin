// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operation.sol";

interface IORMakerDeposit {
    event LogChallengeInfo(
        address indexed factory,
        bytes32 id,
        OperationsLib.challengeInfo challenge,
        OperationsLib.txInfo txInfo
    );
    event LogChallengerCompensation(
        address indexed factory,
        bytes32 challengeId,
        uint256 refund,
        uint256 refundPledged,
        uint256 compensate
    );
    event LogLPAction(bytes32 indexed pairId, bytes32 lpId, OperationsLib.lpInfo lpinfo);
    event LogLPPause(bytes32 indexed pairId, bytes32 lpId, OperationsLib.lpInfo lpinfo);
    event LogLPRestart(bytes32 indexed pairId, bytes32 indexed lpId, uint256 gasFee, uint256 tradingFee);
    event LogLPStop(bytes32 indexed pairId, bytes32 lpId, OperationsLib.lpInfo lpinfo);
    event LogLPUpdate(bytes32 indexed pairId, bytes32 indexed lpId, uint256 gasFee, uint256 tradingFee);
    event LogLPUserStop(bytes32 indexed pairId, bytes32 lpId);
    event Deposit(address caller, uint256 amount);

    function challengePleged() external view returns (uint256);

    function challengerMakeGood(bytes32 challengeID) external;

    function getPairsByChain(uint256 _chainId) external view returns (bytes32[] memory);

    function getPairsByPledgeToken(address _token) external view returns (bytes32[] memory);

    function getPledgeBalance(address _tokenAddress) external view returns (uint256);

    function getPledgeBalanceByChainToken(uint256 _chainId, address _tokenAddress) external view returns (uint256);

    function idleAmount(address tokenAddress) external view returns (uint256);

    function initialize(address _owner) external;

    function lpAction(OperationsLib.lpInfo[] memory _lpinfos, bytes32[][] memory pairProof) external payable;

    function lpInfo(bytes32)
        external
        view
        returns (
            bytes32 lpId,
            uint256 stopTime,
            uint256 startTime
        );

    function lpPause(OperationsLib.lpInfo[] memory _lpinfos) external;

    function lpRestart(OperationsLib.lpRestart[] memory _lps) external;

    function lpStop(OperationsLib.lpInfo[] memory _lpinfos) external;

    function lpUpdate(OperationsLib.lpRestart[] memory _lpinfos) external;

    function makerChallenger(
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
        bytes32[] memory _makerProof
    ) external;

    // function getMakerFactory() external view returns (address);

    function pairExist(uint256 chainId, bytes32 pairId) external view returns (bool);

    // function pairExist(address pledgeToken, bytes32 pairId) external view returns (bool);

    function pledgeTokenLPStopDealyTime(address) external view returns (uint256);

    function userChallenge(OperationsLib.txInfo memory _txinfo, bytes32[] memory _txproof) external payable;

    function userWithDraw(OperationsLib.txInfo memory _userTx, OperationsLib.lpInfo memory _lpinfo) external;

    function withDrawAssert(uint256 amount, address tokenAddress) external;
}
