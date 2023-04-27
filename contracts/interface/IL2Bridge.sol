pragma solidity ^0.8.17;
interface IL2Bridge {
    function handleMessage(bytes calldata message) external;
}