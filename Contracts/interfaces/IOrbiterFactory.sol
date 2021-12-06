// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import "./../Operations.sol";

/// @title The interface for the Orbiter Factory
/// @notice The Orbiter Factory facilitates creation of Orbiter makers'contract and common parameters
interface IOrbiterFactory {

    /// @notice Emitted when the owner of the factory is changed
    /// @param oldOwner The owner before the owner was changed
    /// @param newOwner The owner after the owner was changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when a deposit contrract is created
    /// @param makerAddress
    /// @param makerDepositAddress
    event MakerCreated(
        address indexed makerAddress,
        address indexed makerDepositAddress
    );

    /// @notice Returns the current owner of the factory
    /// @dev Can be changed by the current owner via setOwner
    /// @return The address of the factory owner
    function owner() external view returns (address);

    /// @notice Updates the owner of the factory
    /// @dev Must be called by the current owner
    /// @param _owner The new owner of the factory
    function setOwner(address _owner) external;

    /// @notice Creat a deposit contract with msg.sender
    function createDepositContract() external returns (address depositContract);

    function getChainInfo(uint256 chainID) external returns(Operations.chainInfo memory);

    function setChainInfo(uint256 chainID,uint256 batchLimit,uint256 maxDisputeTime) external;


    function setProtocal(address protocalAddress) external;

    function isSupportProtocal(address protocalAddress) external returns(bool);

    function getStartDelayTime()  external returns (uint256);

    function getStopDelayTime() external returns (uint256);
}
