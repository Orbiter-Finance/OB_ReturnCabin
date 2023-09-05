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
import {MerkleTreeVerification} from "./ORMerkleTree.sol";

contract ORFeeManager is IORFeeManager, MerkleTreeVerification, Ownable, ReentrancyGuard {
    using HelperLib for bytes;
    using SafeERC20 for IERC20;

    // Ownable._owner use a slot
    IORManager private immutable _manager;
    IVerifier private immutable verifier;
    ChallengeStatus public challengeStatus;
    Submission public submissions;

    mapping(address => DealerInfo) private _dealers;
    mapping(address => uint) public submitter;
    mapping(bytes32 => bool) public withdrawLock;

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

    function withdrawLockCheck(SMTLeaf calldata smtLeaves) external view returns (bool) {
        return withdrawLock[keccak256(abi.encode(smtLeaves, submissions.submitTimestamp))];
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
        SMTLeaf[] calldata smtLeaves,
        MergeValue[][] calldata siblings,
        uint256[] calldata bitmaps,
        uint256[] calldata withdrawAmount
    ) external nonReentrant {
        require(durationCheck() == FeeMangerDuration.withdraw, "WE");
        require(challengeStatus == ChallengeStatus.none, "WDC");
        bytes32 profitRoot = submissions.profitRoot;
        for (uint i = 0; i < smtLeaves.length; ) {
            require(msg.sender == smtLeaves[i].key.user, "NU");
            require(withdrawLock[keccak256(abi.encode(smtLeaves[i], submissions.submitTimestamp))] == false, "WL");
            require(withdrawAmount[i] <= smtLeaves[i].value.amount, "UIF");
            require(
                MerkleTreeVerification.verify(
                    keccak256(abi.encode(smtLeaves[i].key)),
                    keccak256(abi.encode(smtLeaves[i].value)),
                    bitmaps[i],
                    profitRoot,
                    siblings[i]
                ),
                "merkle root verify failed"
            );
            unchecked {
                i += 1;
            }
        }

        for (uint i = 0; i < smtLeaves.length; ) {
            withdrawLock[keccak256(abi.encode(smtLeaves[i], submissions.submitTimestamp))] = true;
            if (smtLeaves[i].value.token != address(0)) {
                IERC20(smtLeaves[i].value.token).safeTransfer(msg.sender, withdrawAmount[i]);
            } else {
                (bool success, ) = payable(msg.sender).call{value: withdrawAmount[i], gas: type(uint256).max}("");
                require(success, "ETH: IF");
            }
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
        require(_submitter == IORManager(_manager).submitter(), "NS");
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
