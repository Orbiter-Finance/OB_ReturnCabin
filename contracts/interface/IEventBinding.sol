pragma solidity ^0.8.17;
import "../library/Type.sol";

interface IEventBinding {
    function getResponseResult(Types.Transaction memory _tx,Types.Pair memory pair) external view returns (bytes32);
}
