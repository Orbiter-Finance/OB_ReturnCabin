// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operation.sol";

interface IORMakerDeposit {
    event LogChallengeInfo(
        address indexed makerPool,
        bytes32 id,
        OperationsLib.challengeInfo challenge,
        OperationsLib.txInfo txInfo
    );
    event LogChallengerMakeGood(address indexed makerPool, bytes32 id, OperationsLib.challengeInfo challenge);
    event LogLPPause(bytes32 indexed pairId, bytes32 lpId, OperationsLib.lpInfo lpinfo);
    event LogLPStop(bytes32 indexed pairId, bytes32 lpId, OperationsLib.lpInfo lpinfo);
    event LogLPUserStop(bytes32 indexed pairId, bytes32 lpId);
    event LogLPAction(bytes32 indexed pairId, bytes32 lpId, OperationsLib.lpInfo lpinfo);
    event LogLPRestart(bytes32 indexed pairId, bytes32 indexed lpId, uint256 gasFee, uint256 tradingFee);
    event LogLPUpdate(bytes32 indexed pairId, bytes32 indexed lpId, uint256 gasFee, uint256 tradingFee);

    function lpAction(OperationsLib.lpInfo[] memory _lpinfos, bytes32[][] memory pairProof) external payable;

    function lpPause(OperationsLib.lpInfo[] memory _lpinfos) external;

    function lpRestart(OperationsLib.lpRestart[] memory _lps) external;

    function lpStop(OperationsLib.lpInfo[] memory _lpinfos) external;

    function lpUpdate(OperationsLib.lpChange[] memory _lpinfos) external;

    function pledgeTokenLPStopDealyTime(address) external view returns (uint256);

    function calcLpPledgeAmount(OperationsLib.calcLpNeedPledgeAmountParams[] memory _lpinfos)
        external
        view
        returns (OperationsLib.lpPledgeCalculate[] memory, uint256 totalPledgeValue);

    function challengerMakeGood(bytes32 challengeID) external;

    function getPairsByChain(uint256 _chainId) external view returns (bytes32[] memory);

    function getPairsByPledgeToken(address _token) external view returns (bytes32[] memory);

    function getPledgeBalance(address _tokenAddress) external view returns (uint256);

    function getPledgeBalanceByChainToken(uint256 _chainId, address _tokenAddress) external view returns (uint256);

    function idleAmount(address tokenAddress) external view returns (uint256);

    function initialize(address _owner, address _makerFactory) external;

    function lpInfo(bytes32)
        external
        view
        returns (
            bytes32 lpId,
            uint256 stopTime,
            uint256 startTime
        );

    function makerChallenger(
        OperationsLib.txInfo memory _userTx,
        OperationsLib.txInfo memory _makerTx,
        bytes32[] memory _makerProof
    ) external;

    function makerFactory() external view returns (address);

    function pairExist(uint256 chainId, bytes32 pairId) external view returns (bool);

    function pairExist(address pledgeToken, bytes32 pairId) external view returns (bool);

    function userChallenge(OperationsLib.txInfo memory _txinfo, bytes32[] memory _txproof) external payable;

    function userWithDraw(OperationsLib.txInfo memory _userTx, OperationsLib.lpInfo memory _lpinfo) external;

    function withDrawAssert(uint256 amount, address tokenAddress) external;
}
