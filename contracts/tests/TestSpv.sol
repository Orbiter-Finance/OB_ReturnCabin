// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {RuleLib} from "../library/RuleLib.sol";
import {HelperLib} from "../library/HelperLib.sol";
import {IVerifierRouter} from "../zkp/IVerifierRouter.sol";
import {IOREventBinding} from "../interface/IOREventBinding.sol";

import {RLPReader} from "../library/RLPReader.sol";

contract testSpv {
    using HelperLib for bytes;
    // using RuleLib for bytes;
    using RLPReader for bytes;
    address public v_address;

    // constructor(address verifier) {
    //     v_address = verifier;
    // }

    function set_v(address _v) public {
        v_address = _v;
    }

    function verifyProof(bytes calldata input) external returns (bool) {
        require(v_address != address(0));
        (bool success, ) = v_address.call(input);
        require(success, "verify fail");
        return success;
    }

    function verifyProofXinstance(bytes calldata input, uint256 instanceBytesLength) external view {
        require(IVerifierRouter(v_address).verify(input, instanceBytesLength), "verify fail");
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

    function createFreezeTokenSlotKey(uint256 chainId, uint256 token) external pure returns (uint256 slotK) {
        slotK = uint256(abi.encode(abi.encode(uint64(chainId), token).hash(), 3).hash());
    }

    function createChainInfoSlotKey(uint256 chainId) external pure returns (uint256 slotK) {
        slotK = uint256(abi.encode(chainId, 2).hash());
    }

    function createEncodeRule(RuleLib.Rule calldata rule) external pure returns (uint256 encodeRule) {
        encodeRule = uint256(abi.encode(rule).hash());
    }

    function parseSourceProof(bytes calldata proofData) external pure returns (HelperLib.PublicInputDataSource memory) {
        return proofData.parsePublicInputSource();
    }

    function parseDestProof(bytes calldata proofData) external pure returns (HelperLib.PublicInputDataDest memory) {
        return proofData.parsePublicInputDest();
    }

    function encodeResponseMakers(uint256[] calldata responseMakers) external pure returns (bytes memory) {
        return abi.encode(responseMakers);
    }

    function calculateDestAmount(
        RuleLib.Rule calldata rule,
        address ebc,
        uint64 chain_id,
        uint256 amount
    ) external pure returns (uint256 destAmount) {
        RuleLib.RuleOneway memory ro = RuleLib.convertToOneway(rule, chain_id);
        destAmount = IOREventBinding(ebc).getResponseAmountFromIntent(
            IOREventBinding(ebc).getResponseIntent(amount, ro)
        );
    }

    // function decodeRLPRule(bytes calldata rlpBytes) external pure returns (RuleLib.Rule memory rule) {
    // rlpBytes.decodeRule();
    // RLPReader.RLPItem[] memory ls;
    // ls = rlpBytes.decodeRule();
    // (ls);
    // }

    // function someFunctionThatTakesAnEncodedItem(bytes memory rlpBytes) public pure {
    // RLPReader.RLPItem[] memory ls = rlpBytes.toRlpItem().toList(); // must convert to an rlpItem first!

    // RLPReader.RLPItem memory item = ls[0]; // the encoding of [1, "nested"].
    // item.toList()[0].toUint(); // 1
    // string(item.toList()[1].toBytes()); // "nested"

    // ls[1].toUint(); // 2
    // ls[2].toAddress(); // 0x<Address>
    // }

    // function RLPEncodeRule(RuleLib.Rule calldata rule) external pure returns (bytes memory) {
    //     return RLPReader.encodeRule(rule);
    // }

    // function getRLPItem(bytes calldata rlpBytes) internal pure returns (RLPReader.RLPItem memory item) {
    //     item = RLPReader.toRLPItem(rlpBytes);
    // }

    // function getoffset(RLPReader.RLPItem memory items) internal pure returns (uint offset) {
    //     offset = RLPReader.payloadOffset(items.len, items.memPtr);
    // }

    // function decodeRLPRules(bytes calldata rlpBytes) external pure returns (RuleLib.Rule memory rule) {
    // RLPReader.RLPItem memory item;
    // uint len;
    // RLPReader.RLPItem memory items = rlpBytes.toRLPItem();

    // uint offset = RLPReader.payloadOffset(getRLPItem(rlpBytes));
    // uint value;

    // for (uint i = 0; i < 18; i++) {
    //     item = RLPReader.toRLPItem(slice(rlpBytes, offset));
    //     len = item.len;
    //     value = RLPReader.toUint(item);

    // if (i == 0) rule.chainId0 = uint64(value);
    // else if (i == 1) rule.chainId1 = uint64(value);
    // else if (i == 2) rule.status0 = uint8(value);
    // else if (i == 3) rule.status1 = uint8(value);
    // else if (i == 4) rule.token0 = value;
    // else if (i == 5) rule.token1 = value;
    // else if (i == 6) rule.minPrice0 = uint128(value);
    // else if (i == 7) rule.minPrice1 = uint128(value);
    // else if (i == 8) rule.maxPrice0 = uint128(value);
    // else if (i == 9) rule.maxPrice1 = uint128(value);
    // else if (i == 10) rule.withholdingFee0 = uint128(value);
    // else if (i == 11) rule.withholdingFee1 = uint128(value);
    // else if (i == 12) rule.tradingFee0 = uint32(value);
    // else if (i == 13) rule.tradingFee1 = uint32(value);
    // else if (i == 14) rule.responseTime0 = uint32(value);
    // else if (i == 15) rule.responseTime1 = uint32(value);
    // else if (i == 16) rule.compensationRatio0 = uint32(value);
    // else if (i == 17) rule.compensationRatio1 = uint32(value);

    //     offset += len;
    // }
    // }

    // function slice(bytes memory data, uint start) internal pure returns (bytes memory) {
    //     bytes memory result = new bytes(data.length - start);
    //     for (uint i = 0; i < result.length; i++) {
    //         result[i] = data[i + start];
    //     }
    //     return result;
    // }
}
