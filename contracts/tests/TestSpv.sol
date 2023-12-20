// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {RuleLib} from "../library/RuleLib.sol";
import {HelperLib} from "../library/HelperLib.sol";
// import {IVerifierRouter} from "../zkp/IVerifierRouter.sol";
import {IOREventBinding} from "../interface/IOREventBinding.sol";
import {RLPReader} from "../library/RLPReader.sol";
import {IORChallengeSpv} from "../interface/IORChallengeSpv.sol";

// import {Mainnet2EraLib} from "../library/Mainnet2EraLib.sol";

// import "hardhat/console.sol";

contract testSpv {
    using HelperLib for bytes;
    // using Mainnet2EraLib for bytes;
    using RLPReader for bytes;
    address public v_address;

    constructor(address _v) {
        v_address = _v;
    }

    function set_v(address _v) public {
        v_address = _v;
    }

    function verifyProof(bytes calldata input) external returns (bool) {
        require(v_address != address(0));
        (bool success, ) = v_address.call(input);
        require(success, "verify fail");
        return success;
    }

    // function verifyProofXinstance(bytes calldata input, uint256 instanceBytesLength) external view {
    //     require(IVerifierRouter(v_address).verify(input, instanceBytesLength), "verify fail");
    // }

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

    // function parseSourceProof(bytes calldata proofData) external pure returns (HelperLib.PublicInputDataSource memory) {
    //     return proofData.parsePublicInputSource();
    // }

    // function parseDestProof(bytes calldata proofData) external pure returns (HelperLib.PublicInputDataDest memory) {
    //     return proofData.parsePublicInputDest();
    // }

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

    function verifySourceTx(bytes calldata zkProof, address spvAddress) external returns (bool) {
        bool succeed = IORChallengeSpv(spvAddress).verifySourceTx(zkProof);
        require(succeed, "verify fail");
        return succeed;
    }

    function verifyDestTx(bytes calldata zkProof, address spvAddress) external returns (bool) {
        bool succeed = IORChallengeSpv(spvAddress).verifyDestTx(zkProof);
        require(succeed, "verify fail");
        return succeed;
    }

    struct verifiedDataInfo {
        uint256 minChallengeSecond;
        uint256 maxChallengeSecond;
        uint256 nonce;
        uint256 destChainId;
        uint256 from;
        uint256 destToken;
        uint256 destAmount;
        uint256 responseMakersHash;
        uint256 responseTime;
    }

    function encodeVerifiedData(verifiedDataInfo calldata verifiedSourceTxData) external pure returns (bytes32) {
        return abi.encode(verifiedSourceTxData).hash();
    }
}
