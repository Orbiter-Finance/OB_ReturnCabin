// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Interface for MakerFactory contract.
 * @dev This interface defines the external functions and getter methods available on the MakerFactory contract.
 */
interface IMakerFactory {
    /**
     * @notice Set the address of the manager.
     * @param _manager The address of the manager contract.
     */
    function setManager(address _manager) external;

    /**
     * @notice Set the maximum number of Maker instances that can be created.
     * @param _makerMaxLimit The maximum number of Maker instances that can be created.
     */
    function setMakerMaxLimit(uint256 _makerMaxLimit) external;

    /**
     * @notice Create a new Maker instance for the caller.
     */
    function createMaker() external;

    /**
     * @notice Get the address of the Maker instance owned by a given address.
     * @param _owner The address of the Maker instance owner.
     * @return The address of the Maker instance owned by the given address.
     */
    function makerByOwner(address _owner) external view returns (address);

    /**
     * @notice Get the address of the L2 receive contract for a given Maker instance.
     * @param _maker The address of the Maker instance.
     * @return The address of the L2 receive contract for the given Maker instance.
     */
    function makerL2ReceiveContract(address _maker) external view returns (address);
}
