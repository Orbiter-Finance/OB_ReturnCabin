// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IORFeeManager} from "./interface/IORFeeManager.sol";
import {IORManager} from "./interface/IORManager.sol";
import {HelperLib} from "./library/HelperLib.sol";
import {ConstantsLib} from "./library/ConstantsLib.sol";
import {IVerifier} from "./interface/IVerifier.sol";
import {MerkleTreeLib} from "./library/MerkleTreeLib.sol";
import {MerkleTreeVerification} from "./library/ORMerkleTree.sol";

contract ORFeeManager is IORFeeManager, Ownable, ReentrancyGuard {
    using HelperLib for bytes;
    using SafeERC20 for IERC20;
    using MerkleTreeVerification for bytes32;

    // Ownable._owner use a slot
    IORManager private immutable _manager;
    IVerifier private immutable verifier;
    ChallengeStatus public challengeStatus;
    Submission public submissions;

    mapping(address => DealerInfo) private _dealers;
    mapping(address => uint) public submitter;
    // mapping(bytes32 => bool) public withdrawLock;
    mapping(address => uint64) public withdrawLock;

    modifier isChanllengerQualified() {
        require(address(msg.sender).balance >= address(IORManager(_manager).submitter()).balance, "NF");
        _;
    }

    function durationCheck() public view returns (FeeMangerDuration duration) {
        uint challengeEnd = submissions.submitTimestamp + ConstantsLib.DEALER_WITHDRAW_DELAY;
        if (block.timestamp <= challengeEnd) {
            return FeeMangerDuration.challenge;
        }

        uint mod = (block.timestamp - challengeEnd) % (ConstantsLib.WITHDRAW_DURATION + ConstantsLib.LOCK_DURATION);
        if (mod <= ConstantsLib.WITHDRAW_DURATION) {
            return FeeMangerDuration.withdraw;
        } else {
            return FeeMangerDuration.lock;
        }
    }

    function withdrawLockCheck(MerkleTreeLib.SMTKey calldata key) external view returns (bool) {
        return withdrawLock[key.user] < submissions.submitTimestamp ? true : false;
    }

    receive() external payable {
        emit ETHDeposit(msg.sender, msg.value);
    }

    constructor(address owner_, address manager_, IVerifier _verifier) {
        require(owner_ != address(0), "OZ");
        require(manager_ != address(0), "MZ");

        _transferOwnership(owner_);
        _manager = IORManager(manager_);
        verifier = _verifier;
        submissions.submitTimestamp = uint64(ConstantsLib.DEALER_WITHDRAW_DELAY + ConstantsLib.WITHDRAW_DURATION);
    }

    function withdrawVerification(
        MerkleTreeLib.SMTLeaf[] calldata smtLeaves,
        MerkleTreeLib.MergeValue[][] calldata siblings,
        uint8[] calldata startIndex,
        bytes32[] calldata firstZeroBits,
        uint256[] calldata bitmaps,
        uint256[] calldata withdrawAmount
    ) external nonReentrant {
        require(durationCheck() == FeeMangerDuration.withdraw, "WE");
        require(challengeStatus == ChallengeStatus.none, "WDC");
        require(withdrawLock[msg.sender] < submissions.submitTimestamp, "WL");
        withdrawLock[msg.sender] = submissions.submitTimestamp;
        for (uint i = 0; i < smtLeaves.length; ) {
            require(msg.sender == smtLeaves[i].key.user, "NU");
            require(withdrawAmount[i] <= smtLeaves[i].value.amount, "UIF");
            require(
                keccak256(abi.encode(smtLeaves[i].key)).verify(
                    keccak256(abi.encode(smtLeaves[i].value)),
                    bitmaps[i],
                    submissions.profitRoot,
                    firstZeroBits[i],
                    startIndex[i],
                    siblings[i]
                ),
                "merkle root verify failed"
            );

            // if (smtLeaves[i].value.token != address(0)) {
            //     IERC20(smtLeaves[i].value.token).safeTransfer(msg.sender, withdrawAmount[i]);
            // } else {
            //     (bool success, ) = payable(msg.sender).call{value: withdrawAmount[i], gas: type(uint256).max}("");
            //     require(success, "ETH: IF");
            // }
            emit Withdraw(
                msg.sender,
                smtLeaves[i].value.chainId,
                smtLeaves[i].value.token,
                smtLeaves[i].value.debt,
                withdrawAmount[i]
            );
            unchecked {
                i += 1;
            }
        }
    }

    function submit(
        uint64 startBlock,
        uint64 endBlock,
        bytes32 profitRoot,
        bytes32 stateTransTreeRoot
    ) external override nonReentrant {
        require(submitter[msg.sender] != 0, "NS");
        require(challengeStatus == ChallengeStatus.none, "SDC");
        require(durationCheck() == FeeMangerDuration.lock, "NL2");
        require(endBlock > startBlock, "EB");
        Submission memory submission = submissions;
        require(startBlock == submission.endBlock, "BE");

        submissions = Submission(startBlock, endBlock, uint64(block.timestamp), profitRoot, stateTransTreeRoot);

        // challengeStatus = ChallengeStatus.challengeDuration;
        emit SubmissionUpdated(startBlock, endBlock, uint64(block.timestamp), profitRoot, stateTransTreeRoot);
    }

    function updateDealer(uint feeRatio, bytes calldata extraInfo) external {
        bytes32 extraInfoHash = extraInfo.hash();
        _dealers[msg.sender] = DealerInfo(feeRatio, extraInfoHash);
        emit DealerUpdated(msg.sender, feeRatio, extraInfo);
    }

    function getDealerInfo(address dealer) external view returns (DealerInfo memory) {
        return _dealers[dealer];
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "OZ");
        _transferOwnership(newOwner);
    }

    function registerSubmitter(uint marginAmount, address _submitter) external override onlyOwner {
        require(_submitter == IORManager(_manager).submitter(), "NSR");
        submitter[_submitter] = marginAmount;
        emit SubmitterRegistered(_submitter, marginAmount);
    }

    function getCurrentBlockInfo() external view override returns (Submission memory) {}

    function startChallenge(uint marginAmount, address _submitter) public override isChanllengerQualified nonReentrant {
        challengeStatus = ChallengeStatus.challengeAccepted;
        (marginAmount, _submitter);
    }

    function responsePositioning(bytes calldata response) public override {
        (response);
        endChallenge();
    }

    function endChallenge() internal nonReentrant {
        challengeStatus = ChallengeStatus.none;
    }
}
