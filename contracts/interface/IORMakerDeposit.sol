// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../library/Operations.sol";

interface IORMakerDeposit {
    event ColumnArrayUpdated(
        address indexed impl,
        bytes32 columnArrayHash,
        address[] dealers,
        address[] ebcs,
        uint16[] chainIds
    );
    event SpvUpdated(address indexed impl, uint16 chainId, address spv);
    event ResponseMakersUpdated(address indexed impl, address[] responseMakers);

    function initialize(address owner_) external;

    function owner() external view returns (address);

    function mdcFactory() external view returns (address);

    function columnArrayHash() external view returns (bytes32);

    function updateColumnArray(
        address[] calldata dealers,
        address[] calldata ebcs,
        uint16[] calldata chainIds
    ) external;

    function spv(uint16 chainId) external view returns (address);

    function updateSpvs(address[] calldata spvs, uint16[] calldata chainIds) external;

    function responseMakers() external view returns (address[] memory);

    function updateResponseMakers(address[] calldata responseMakers_, uint[] calldata indexs) external;

    // enum RuleStatus {
    //     Stoped,
    //     Activated,
    //     Paused
    // }

    // event Deposit(address caller, uint256 amount);
    // event LogChallengeInfo(
    //     address indexed factory,
    //     bytes32 id,
    //     OperationsLib.challengeInfo challenge,
    //     OperationsLib.Transaction txInfo
    // );
    // event LogChallengerCompensation(
    //     address indexed factory,
    //     bytes32 challengeId,
    //     uint256 refund,
    //     uint256 refundPledged,
    //     uint256 compensate
    // );
    // event LogLPAction(bytes32 indexed pairId, bytes32 lpId, OperationsLib.LPStruct lpinfo);
    // event LogLPPause(bytes32 indexed pairId, bytes32 lpId, OperationsLib.lpInfo lpinfo);
    // event LogLPRestart(bytes32 indexed pairId, bytes32 indexed lpId, uint256 gasFee, uint256 tradingFee);
    // event LogLPStop(bytes32 indexed pairId, bytes32 lpId, OperationsLib.lpInfo lpinfo);
    // event LogLPUpdate(bytes32 indexed pairId, bytes32 indexed lpId, uint256 gasFee, uint256 tradingFee);
    // event LogLPUserStop(bytes32 indexed pairId, bytes32 lpId);

    // function challengePleged() external view returns (uint256);

    // function challengerMakeGood(OperationsLib.Transaction calldata _userTx) external;

    // // function getMakerFactory() external view returns (address);

    // // function getPairsByChain(uint256 _chainId)
    // //     external
    // //     view
    // //     returns (bytes32[] memory);

    // // function getPairsByPledgeToken(address _token) external view returns (bytes32[] memory);

    // // function getPledgeBalance(address _tokenAddress)
    // //     external
    // //     view
    // //     returns (uint256);

    // // function getPledgeBalanceByChainToken(
    // //     uint256 _chainId,
    // //     address _tokenAddress
    // // ) external view returns (uint256);

    // function idleAmount(address tokenAddress) external view returns (uint256);

    // function initialize(address _owner) external;

    // function lpAction(OperationsLib.LPActionStruct[] memory _lps) external payable;

    // function lpData(
    //     bytes32
    // )
    //     external
    //     view
    //     returns (
    //         bytes32 pairId,
    //         uint256 minPrice,
    //         uint256 maxPrice,
    //         uint256 gasFee,
    //         uint256 tradingFee,
    //         uint256 startTime,
    //         uint256 stopTime
    //     );

    // // function lpInfo(bytes32)
    // //     external
    // //     view
    // //     returns (
    // //         bytes32 lpId,
    // //         uint256 stopTime,
    // //         uint256 startTime
    // //     );

    // // function lpPause(bytes32[] memory _lpIds) external;

    // // function lpRestart(OperationsLib.LPUpdateStruct[] memory _lps) external;

    // // function lpStop(bytes32[] memory _lpIds) external;

    // // function lpUpdate(OperationsLib.LPUpdateStruct[] memory _lpfs) external;

    // function makerChallenge(OperationsLib.Transaction calldata _userTx, bytes calldata makerTxBytes) external;

    // // function pairExist(uint256 chainId, bytes32 pairId)
    // //     external
    // //     view
    // //     returns (bool);

    // function pledgeTokenLPStopDealyTime(address) external view returns (uint256);

    // function userChallenge(bytes calldata userTxBytes) external payable;

    // function userWithDraw(OperationsLib.Transaction calldata _userTx, OperationsLib.LPStruct calldata _lp) external;

    // function withDrawAssert(uint256 amount, address tokenAddress) external;

    // receive() external payable;
}
