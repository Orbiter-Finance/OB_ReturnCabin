// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {RuleLib} from "../library/RuleLib.sol";
import {HelperLib} from "../library/HelperLib.sol";

contract testSpv {
    using HelperLib for bytes;
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

    function createFreezeTokenSlotKey(uint chainId, uint token) external pure returns (uint slotK) {
        slotK = uint(abi.encode(abi.encode(uint64(chainId), token).hash(), 3).hash());
    }

    function createChainInfoSlotKey(uint chainId) external pure returns (uint slotK) {
        slotK = uint(abi.encode(chainId, 2).hash());
    }

    function createEncodeRule(RuleLib.Rule calldata rule) external pure returns (uint encodeRule) {
        encodeRule = uint(abi.encode(rule).hash());
    }
}
