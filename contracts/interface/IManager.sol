// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "../library/Type.sol";
/**

@title Manager Interface
@notice Interface for the Manager contract, which is responsible for managing chains and tokens.
@dev This interface includes functions for registering SPVs, chains, and tokens, as well as getting information about tokens.
*/
interface IManager {

    /**
     * @notice Registers an SPV for a specific chain.
     * @dev Only the owner of the contract can call this function.
     * @param chain The ID of the chain to register the SPV for.
     * @param addr The address of the SPV to register.
     */
    function registerSPV(uint256 chain, address addr) external;

    /**
     * @notice Registers a new chain with the specified ID and batch limit, along with its associated tokens.
     * @dev Only the owner of the contract can call this function.
     * @param id The ID of the chain to register.
     * @param batchLimit The batch limit for the chain.
     * @param tokenInfos An array of TokenInfo structs representing the tokens associated with the chain.
     */
    function registerChain(uint256 id, uint256 batchLimit, Types.TokenInfo[] memory tokenInfos) external;

    /**
     * @notice Registers a new token associated with a specific chain.
     * @dev Only the owner of the contract can call this function.
     * @param chainId The ID of the chain the token is associated with.
     * @param tokenPrecision The precision of the token.
     * @param tokenAddress The address of the token contract.
     * @param mainAddress The address of the main contract for the token.
     */
    function registerToken(uint256 chainId, uint256 tokenPrecision, address tokenAddress, address mainAddress) external;

    /**
     * @notice Gets the TokenInfo struct for a specific token on a specific chain.
     * @param chainID The ID of the chain the token is associated with.
     * @param tokenAddress The address of the token contract.
     * @return The TokenInfo struct representing the token on the specified chain.
     */
    function getTokenInfo(uint256 chainID, address tokenAddress) external view returns (Types.TokenInfo memory);
}
