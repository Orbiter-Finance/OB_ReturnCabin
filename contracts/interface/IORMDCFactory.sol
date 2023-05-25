// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./IORManager.sol";

interface IORMDCFactory {
    event MDCCreated(address maker, address mdc);

    function manager() external view returns (address);

    function implementation() external view returns (address);

    function mdcCreatedTotal() external view returns (uint);

    function createMDC() external;

    function predictMDCAddress() external view returns (address);
}
