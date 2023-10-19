// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {RuleLib} from "../library/RuleLib.sol";

contract testSpv {
    address public v_address;

    constructor(address verifier) {
        v_address = verifier;
    }

    function set_v(address _v) public {
        v_address = _v;
    }

    function parseProofData(
        bytes calldata proofData
    )
        external
        pure
        returns (bytes memory _proof, bytes32 blockHash, bytes32 toAddress, uint256 transferAmount, uint256 timestamp)
    {
        _proof = proofData[0:384];
        blockHash = bytes32((uint256(bytes32(proofData[384:416])) << 128) | uint256(bytes32(proofData[416:448])));
        toAddress = bytes32(uint256(bytes32(proofData[448:480])));
        transferAmount = uint256(bytes32(proofData[480:512]));
        timestamp = uint256(bytes32(proofData[512:544]));
    }

    function verifyProof(bytes calldata input) external returns (bool) {
        require(v_address != address(0));
        (bool success, ) = v_address.call(input);
        require(success, "verify fail");
        return success;
    }

    function encodeRawDatas(
        address[] calldata dealers,
        address[] calldata ebcs,
        uint64[] calldata chainIds,
        address ebc,
        RuleLib.Rule calldata rule
    ) external pure returns (bytes memory rawDatas) {
        return abi.encode(dealers, ebcs, chainIds, ebc, rule);
    }

    function encoderawDatas(
        address[] calldata dealers,
        address[] calldata ebcs,
        uint64[] calldata chainIds
    ) external pure returns (bytes memory rawDatas) {
        return abi.encode(dealers, ebcs, chainIds);
    }

    function decoderawDatas(
        bytes calldata rawDatas
    ) external pure returns (address[] memory dealers, address[] memory ebcs, uint64[] memory chainIds) {
        (dealers, ebcs, chainIds) = abi.decode(rawDatas, (address[], address[], uint64[]));
    }

    function decodeRawDatas(
        bytes calldata rawDatas
    )
        external
        pure
        returns (
            address[] memory dealers,
            address[] memory ebcs,
            uint64[] memory chainIds,
            address ebc,
            RuleLib.Rule memory rule
        )
    {
        (dealers, ebcs, chainIds, ebc, rule) = abi.decode(
            rawDatas,
            (address[], address[], uint64[], address, RuleLib.Rule)
        );
    }
}
