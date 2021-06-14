pragma solidity 0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


ontract L1_PushManServer is Ownable {
    constructor(
    ) public {
    }

    /**
     * @dev Mint new hToken for the account
     * @param account The account being minted for
     * @param amount The amount being minted
     */
    function mint(address account, uint256 amount) external onlyOwner {
    }

    /**
     * @dev Burn hToken from the account
     * @param account The account being burned from
     * @param amount The amount being burned
     */
    function burn(address account, uint256 amount) external onlyOwner {
    }
}