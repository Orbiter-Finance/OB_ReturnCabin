pragma solidity ^0.8.17;
import "../library/Type.sol";

interface IEventBinding {
    function getResponseHash(Types.Transaction memory tx, bool isSource) external view returns (bytes32);
}
