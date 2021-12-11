// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import "hardhat/console.sol";
import './interfaces/IOrbiterFactory.sol';
// import './interfaces/IOrbiterMakerDeposit.sol';
import './Operations.sol';
import './OrbiterMakerDeposit.sol';

/// @title Canonical Orbiter factory
/// @notice Deploys a Orbiter deposit contract controlled by maker
contract OrbiterManager is IOrbiterFactory{
    address public override owner;
    mapping (address=>bool) protocalMap;
    mapping (uint256 => Operations.chainInfo) ChainInfoMap;
    uint256 uChallengePledge = 1 * 10 ** 17;

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);
        console.log("Deploying a OrbiterManager with OrbiterManager");
    }

    function getChainInfo(uint256 chainID) override public returns(Operations.chainInfo memory chainInfo) {
      Operations.chainInfo memory chainInfo = ChainInfoMap[chainID];
      require(chainInfo.chainid != 0, "must have chaininfo");
      return chainInfo;
    }

    function setChainInfo(uint256 chainID,uint256 batchLimit,uint256 maxDisputeTime) override public {
      Operations.chainInfo memory chainInfo = Operations.chainInfo(
          chainID,
          batchLimit,
          maxDisputeTime
      );
      ChainInfoMap[chainID] = chainInfo;
    }

    function setProtocal(address protocalAddress) override public {
      require(protocalAddress != address(0),'protocalAddress must not be address(0)');
      require(protocalMap[protocalAddress] == false, 'protocalAddress must be new');
      protocalMap[protocalAddress] = true;
    }

    function isSupportProtocal(address protocalAddress) override public returns(bool isSuccess) {
      require(protocalAddress != address(0),'protocalAddress must not be address(0)');
      return protocalMap[protocalAddress];
    }

    function getStartDelayTime()
        override
        view
        public
        returns (uint256 delayTime)
    {
        uint delayTime = 60;
        return delayTime;
    }

    function getStopDelayTime()
        external
        override
        returns (uint256 delayTime)
    {
        uint delayTime = 60;
        return delayTime;
    }

    /// @inheritdoc IOrbiterFactory
    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IOrbiterFactory
    function createDepositContract() external override returns (address depositContract){
        depositContract = address(new OrbiterMakerDeposit{salt: keccak256(abi.encode(msg.sender))}());
        emit MakerCreated(msg.sender,depositContract);
    }
}
