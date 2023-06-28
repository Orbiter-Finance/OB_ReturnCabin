// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interface/IORMakerDeposit.sol";
import "./interface/IORManager.sol";
import "./interface/IORProtocal.sol";
import "./interface/IORProventh.sol";
import "./interface/IORMDCFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ArrayLib} from "./library/ArrayLib.sol";
import {RuleLib} from "./library/RuleLib.sol";
import {IORChallengeSpv} from "./interface/IORChallengeSpv.sol";

// TODO: for dev
// import "hardhat/console.sol";

contract ORMakerDeposit is IORMakerDeposit {
    using ArrayLib for address[];
    using SafeERC20 for IERC20;

    address private _owner;
    IORMDCFactory private _mdcFactory;
    bytes32 private _columnArrayHash;
    mapping(uint16 => address) private _spvs; // chainId => spvAddress
    address[] private _responseMakers; // Response maker list, not just owner, to improve tps
    mapping(address => RuleLib.RootWithVersion) private _rulesRoots; // ebc => merkleRoot(rules), version
    mapping(address => mapping(bytes32 => uint)) private _pledgeBalances; // ebc => hash(sourceChainId, sourceToken) => pledgeBalance
    mapping(address => uint) private _freezeAssets; // token(ETH: 0) => freezeAmount
    mapping(bytes32 => ChallengeInfo) private _challenges; // hash(sourceChainId, transactionHash) => ChallengeInfo

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function initialize(address owner_) external {
        require(_owner == address(0), "_ONZ");
        require(owner_ != address(0), "OZ");

        _owner = owner_;
        _mdcFactory = IORMDCFactory(msg.sender);
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function mdcFactory() external view returns (address) {
        return address(_mdcFactory);
    }

    function columnArrayHash() external view returns (bytes32) {
        return _columnArrayHash;
    }

    function updateColumnArray(
        address[] calldata dealers,
        address[] calldata ebcs,
        uint16[] calldata chainIds
    ) external onlyOwner {
        require(dealers.length <= 10, "DOF");
        require(ebcs.length <= 10, "EOF");
        require(chainIds.length <= 100, "COF");

        IORManager manager = IORManager(_mdcFactory.manager());
        for (uint i = 0; i < ebcs.length; ) {
            require(manager.ebcIncludes(ebcs[i]), "EI"); // Has invalid ebc

            unchecked {
                i++;
            }
        }

        for (uint i = 0; i < chainIds.length; ) {
            OperationsLib.ChainInfo memory chainInfo = manager.getChainInfo(chainIds[i]);
            require(chainInfo.id > 0, "CI"); // Invalid chainId

            unchecked {
                i++;
            }
        }

        _columnArrayHash = keccak256(abi.encodePacked(dealers, ebcs, chainIds));

        address impl = _mdcFactory.implementation();
        emit ColumnArrayUpdated(impl, _columnArrayHash, dealers, ebcs, chainIds);
    }

    function spv(uint16 chainId) external view returns (address) {
        return _spvs[chainId];
    }

    function updateSpvs(address[] calldata spvs, uint16[] calldata chainIds) external onlyOwner {
        IORManager manager = IORManager(_mdcFactory.manager());
        address impl = _mdcFactory.implementation();

        for (uint i = 0; i < chainIds.length; i++) {
            OperationsLib.ChainInfo memory chainInfo = manager.getChainInfo(chainIds[i]);
            require(chainInfo.id > 0, "CI"); // Invalid chainId

            require(chainInfo.spvs.addressIncludes(spvs[i]), "SI"); // Invalid spv

            _spvs[chainIds[i]] = spvs[i];

            emit SpvUpdated(impl, chainIds[i], spvs[i]);
        }
    }

    function responseMakers() external view returns (address[] memory) {
        return _responseMakers;
    }

    function updateResponseMakers(address[] calldata responseMakers_, uint[] calldata indexs) external onlyOwner {
        unchecked {
            for (uint i = 0; i < responseMakers_.length; i++) {
                if (i < indexs.length) {
                    _responseMakers[indexs[i]] = responseMakers_[i];
                } else {
                    _responseMakers.push(responseMakers_[i]);
                }
            }
        }
        emit ResponseMakersUpdated(_mdcFactory.implementation(), _responseMakers);
    }

    function freezeAssets(address token) external view returns (uint) {
        return _freezeAssets[token];
    }

    function deposit(address token, uint amount) external payable {
        // TODO: This method is useless if it does not need to throw an event
        // ETH received by default
        // ERC20 calls safeTransferFrom, can also call `transfer` send assets to address(this)
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function withdraw(address token, uint amount) external onlyOwner {
        if (token == address(0)) {
            require(address(this).balance - _freezeAssets[token] >= amount, "ETH: IF");

            (bool sent, ) = payable(msg.sender).call{value: amount}("");
            require(sent, "ETH: SE");
        } else {
            uint balance = IERC20(token).balanceOf(address(this));
            require(balance - _freezeAssets[token] >= amount, "ERC20: IF");

            IERC20(token).safeTransfer(msg.sender, amount);
        }
    }

    function rulesRoot(address ebc) external view returns (RuleLib.RootWithVersion memory) {
        return _rulesRoots[ebc];
    }

    function updateRulesRoot(
        address ebc,
        bytes calldata rsc,
        RuleLib.RootWithVersion calldata rootWithVersion,
        uint16[] calldata sourceChainIds,
        uint[] calldata pledgeAmounts
    ) external payable onlyOwner {
        // Prevent unused hints
        rsc;

        _updateRulesRoot(ebc, rootWithVersion);

        require(sourceChainIds.length == pledgeAmounts.length, "SPL");

        uint totalAmount;
        for (uint i = 0; i < sourceChainIds.length; ) {
            bytes32 k = keccak256(abi.encodePacked(sourceChainIds[i], address(0)));

            if (pledgeAmounts[i] > _pledgeBalances[ebc][k]) {
                totalAmount += pledgeAmounts[i] - _pledgeBalances[ebc][k];
            }

            _pledgeBalances[ebc][k] = pledgeAmounts[i];

            unchecked {
                i++;
            }
        }

        require(totalAmount <= msg.value, "IV"); // Insufficient value
    }

    function updateRulesRootERC20(
        address ebc,
        bytes calldata rsc,
        RuleLib.RootWithVersion calldata rootWithVersion,
        uint16[] calldata sourceChainIds,
        uint[] calldata pledgeAmounts,
        address token
    ) external onlyOwner {
        // Prevent unused hints
        rsc;

        _updateRulesRoot(ebc, rootWithVersion);

        require(sourceChainIds.length == pledgeAmounts.length, "SPL");

        for (uint i = 0; i < sourceChainIds.length; ) {
            bytes32 k = keccak256(abi.encodePacked(sourceChainIds[i], token));

            if (pledgeAmounts[i] > _pledgeBalances[ebc][k]) {
                IERC20(token).safeTransferFrom(msg.sender, address(this), pledgeAmounts[i] - _pledgeBalances[ebc][k]);
            }

            unchecked {
                i++;
            }
        }
    }

    function _updateRulesRoot(address ebc, RuleLib.RootWithVersion calldata rootWithVersion) private {
        IORManager manager = IORManager(_mdcFactory.manager());
        require(manager.ebcIncludes(ebc), "EI"); // Invalid ebc

        require(rootWithVersion.root != bytes32(0), "RZ");
        unchecked {
            require(_rulesRoots[ebc].version + 1 == rootWithVersion.version, "VE");
        }

        _rulesRoots[ebc] = rootWithVersion;

        emit RulesRootUpdated(_mdcFactory.implementation(), ebc, rootWithVersion);
    }

    function challenge(
        uint16 sourceChainId,
        bytes32 sourceTxHash,
        address freezeToken,
        uint freezeAmount
    ) external payable {
        bytes32 k = keccak256(abi.encodePacked(sourceChainId, sourceTxHash));
        require(_challenges[k].challengeTime == 0, "CE");

        if (freezeToken == address(0)) {
            require(freezeAmount == msg.value, "IF");
        } else {
            IERC20(freezeToken).safeTransferFrom(msg.sender, address(this), freezeAmount);
        }

        // TODO: Currently it is assumed that the pledged assets of the challenger and the owner are the same

        // Freeze mdc's owner assets
        _freezeAssets[freezeToken] += freezeAmount;

        _challenges[k] = ChallengeInfo(freezeToken, freezeAmount, 0, uint64(block.timestamp), 0, 0, 0);

        // TODO: emit event
    }

    function checkChallenge(bytes32 challengeId) external {
        // TODO: state machine
    }

    function verifyChallengeSource(
        address spvAddress,
        bytes calldata proof,
        bytes32 spvBlockHash,
        IORChallengeSpv.VerifyInfo calldata verifyInfo
    ) external {
        bytes32 verifyInfoHash = keccak256(abi.encode(verifyInfo));

        bool result = IORChallengeSpv(spvAddress).verifyChallenge(proof, spvBlockHash, verifyInfoHash);
        require(result, "VF");

        bytes32 challengeId = keccak256(abi.encodePacked(uint16(verifyInfo.txInfos[0]), verifyInfo.txInfos[1]));
        require(_challenges[challengeId].challengeTime > 0, "CTZ");
        require(_challenges[challengeId].verifiedTime0 == 0, "VT0NZ");

        // TODO, check time interval

        // TODO: Check the address and key of the slot

        _challenges[challengeId].verifiedTime0 = uint64(block.timestamp);

        // TODO: emit events
    }

    function verifyChallengeDest(
        address spvAddress,
        bytes calldata proof,
        bytes32 spvBlockHash,
        IORChallengeSpv.VerifyInfo calldata verifyInfo,
        uint[] calldata verifiedData0
    ) external {
        bytes32 verifyInfoHash = keccak256(abi.encode(verifyInfo));

        bool result = IORChallengeSpv(spvAddress).verifyChallenge(proof, spvBlockHash, verifyInfoHash);
        require(result, "VF");

        bytes32 challengeId = keccak256(abi.encodePacked(uint16(verifyInfo.txInfos[0]), verifyInfo.txInfos[1]));
        require(_challenges[challengeId].verifiedTime0 > 0, "VT0Z");
        require(_challenges[challengeId].verifiedTime1 == 0, "VT1NZ");

        // TODO, check time interval

        // TODO: Check the address and key of the slot

        bytes32 verifiedDataHash0 = keccak256(abi.encode(verifiedData0));
        require(_challenges[challengeId].verifiedDataHash0 == verifiedDataHash0, "VDHI");

        _challenges[challengeId].verifiedTime1 = uint64(block.timestamp);

        // TODO: emit events
    }

    // using EnumerableMap for EnumerableMap.AddressToUintMap;
    // using EnumerableMap for EnumerableMap.Bytes32ToUintMap;
    // using EnumerableSet for EnumerableSet.Bytes32Set;

    // // challenge pleged eth amount
    // uint256 public challengePleged;
    // IORMakerV1Factory public getMakerFactory;
    // address public owner;
    // // pairId->lpPairInfo
    // // mapping(bytes32 => OperationsLib.lpPairInfo) public lpInfo;
    // // challengeInfos
    // mapping(bytes32 => OperationsLib.challengeInfo) private challengeInfos;
    // // After the User forcibly stops LP, Maker delays the withdrawal time.
    // mapping(address => uint256) public pledgeTokenLPStopDealyTime;
    // // source chainID => pledgeToken => amount
    // mapping(uint256 => EnumerableMap.AddressToUintMap) private sourceChainPledgeBalance;
    // // source chainID => pairId => amount
    // mapping(uint256 => EnumerableMap.Bytes32ToUintMap) private sourceChainPairs;

    // // lpId  => LPStruct
    // mapping(bytes32 => OperationsLib.LPStruct) public lpData;
    // // pairId => EffectivePairStruct
    // mapping(bytes32 => OperationsLib.EffectivePairStruct) public effectivePair;
    // // lpId => lp Create timestamp
    // // EnumerableMap.Bytes32ToUintMap private lpDataMapTimestamp;
    // // pledgeToken=> amount
    // EnumerableMap.AddressToUintMap private pledgeBalance;
    // // pledgeToken => pairs
    // // mapping(uint256 => EnumerableSet.Bytes32Set) private pledgeTokenPairs;

    // modifier onlyOwner() {
    //     require(msg.sender == owner, "Ownable: caller is not the owner");
    //     _;
    // }

    // function initialize(address _owner) public {
    //     require(_owner != address(0), "Owner address error");
    //     getMakerFactory = IORMakerV1Factory(msg.sender);
    //     owner = _owner;
    // }

    // function getPledgeBalance(address token) external view returns (uint256) {
    //     (, uint256 value) = pledgeBalance.tryGet(token);
    //     return value;
    // }

    // function getPledgeBalanceByChainToken(uint256 chainId, address token) external view returns (uint256) {
    //     (, uint256 value) = sourceChainPledgeBalance[chainId].tryGet(token);
    //     return value;
    // }

    // function getManager() private view returns (IORManager manager) {
    //     manager = getMakerFactory.getManager();
    // }

    // function idleAmount(address token) public view returns (uint256) {
    //     uint256 balance = 0;
    //     if (token != address(0)) {
    //         IERC20 liquidityToken = IERC20(token);
    //         balance = liquidityToken.balanceOf(address(this));
    //     } else {
    //         balance = address(this).balance;
    //     }
    //     uint256 pledged = this.getPledgeBalance(token);
    //     uint256 idleamount = balance - pledged - challengePleged;
    //     return idleamount;
    // }

    // function calculatePairPledgeAmount(OperationsLib.LPActionStruct[] calldata _lps)
    //     external
    //     view
    //     returns (OperationsLib.CalculatePairPledgeResponseTemp[] memory)
    // {
    //     OperationsLib.CalculatePairPledgeResponseTemp[]
    //         memory tempData = new OperationsLib.CalculatePairPledgeResponseTemp[](_lps.length);
    //     IORManager manager = getManager();
    //     OperationsLib.CalculatePairPledgeResponse[] memory pledgePairListData = manager.calculatePairPledgeAmount(_lps);
    //     require(_lps.length == pledgePairListData.length, "Array inconsistent");
    //     uint256 count;
    //     for (uint256 i = 0; i < _lps.length; ) {
    //         OperationsLib.CalculatePairPledgeResponse memory _pairPledge = pledgePairListData[i];
    //         OperationsLib.LPActionStruct calldata _lp = _lps[i];
    //         address pledgedToken = pledgePairListData[i].pledgedToken;
    //         (,uint256 sourceChain, , , ) = manager.getPairs(_lp.pairId);
    //         // pledged
    //         if (_pairPledge.pledgedValue > 0) {
    //             bool isExist;
    //             for (uint256 j = 0; j < tempData.length; ) {
    //                 OperationsLib.CalculatePairPledgeResponseTemp memory tempItem = tempData[j];
    //                 if (
    //                     tempItem.chainId != 0 &&
    //                     tempItem.pledgedToken == pledgedToken &&
    //                     tempItem.chainId == sourceChain
    //                 ) {
    //                     isExist = true;
    //                     if (_pairPledge.pledgedValue > tempItem.pledgedValue) {
    //                         tempItem.pledgedValue = _pairPledge.pledgedValue;
    //                     }
    //                     break;
    //                 }
    //                 unchecked {
    //                     ++j;
    //                 }
    //             }
    //             if (!isExist) {
    //                 tempData[count] = OperationsLib.CalculatePairPledgeResponseTemp(
    //                     pledgedToken,
    //                     sourceChain,
    //                     _pairPledge.pledgedValue
    //                 );
    //                 count++;
    //             }
    //         }
    //         unchecked {
    //             ++i;
    //         }
    //     }
    //     uint256 accordWithCount = tempData.length - count;
    //     if (accordWithCount > 0) {
    //         assembly {
    //             mstore(tempData, sub(mload(tempData), accordWithCount))
    //         }
    //     }
    //     for (uint256 i = 0; i < tempData.length; ) {
    //         uint256 nowPledgedValue = this.getPledgeBalanceByChainToken(tempData[i].chainId, tempData[i].pledgedToken);
    //         if (tempData[i].pledgedValue > nowPledgedValue) {
    //             tempData[i].pledgedValue = tempData[i].pledgedValue - nowPledgedValue;
    //         } else {
    //             tempData[i].pledgedValue = 0;
    //         }
    //         unchecked {
    //             ++i;
    //         }
    //     }
    //     return tempData;
    // }

    // function lpAction(OperationsLib.LPActionStruct[] calldata _lps) external payable onlyOwner {
    //     IORManager manager = getManager();
    //     OperationsLib.CalculatePairPledgeResponse[] memory pledgePairListData = manager.calculatePairPledgeAmount(_lps);
    //     require(_lps.length == pledgePairListData.length, "Array inconsistent");
    //     uint256 needPledgeValue = 0;
    //     address pledgedToken = pledgePairListData[0].pledgedToken;
    //     for (uint256 i = 0; i < _lps.length; ) {
    //         OperationsLib.CalculatePairPledgeResponse memory _pairPledge = pledgePairListData[i];
    //         require(pledgedToken == _pairPledge.pledgedToken, "The pledgedToken is inconsistent");
    //         OperationsLib.LPActionStruct calldata _lp = _lps[i];
    //         require(_pairPledge.pairId == _lp.pairId, "The pairId is inconsistent");
    //         (,uint256 sourceChain, , , ) = manager.getPairs(_lp.pairId);
    //         OperationsLib.EffectivePairStruct memory effectivePairItem = effectivePair[_lp.pairId];
    //         require(effectivePairItem.lpId == 0, "Pair already exists");
    //         require(effectivePairItem.startTime == 0 && effectivePairItem.stopTime == 0, "LP started");
    //         bytes32 lpId = OperationsLib.getLpID(
    //             _lp.pairId,
    //             address(this),
    //             block.timestamp,
    //             _lp.minPrice,
    //             _lp.maxPrice
    //         );
    //         // bool created = sourceChainPairs[sourceChain].add(_lp.pairId);
    //         // require(created, "Pair already exists");
    //         bool created = sourceChainPairs[sourceChain].set(_lp.pairId, _pairPledge.pledgedValue);
    //         require(created, "Pair already exists");

    //         lpData[lpId] = OperationsLib.LPStruct(
    //             _lp.pairId,
    //             _lp.minPrice,
    //             _pairPledge.maxPrice,
    //             _lp.gasFee,
    //             _lp.tradingFee,
    //             block.timestamp,
    //             0
    //         );
    //         effectivePair[_lp.pairId] = OperationsLib.EffectivePairStruct(lpId, block.timestamp, 0);
    //         // pledged
    //         if (_pairPledge.pledgedValue > 0) {
    //             uint256 nowPledgedValue = this.getPledgeBalanceByChainToken(sourceChain, pledgedToken);
    //             if (_pairPledge.pledgedValue > nowPledgedValue) {
    //                 needPledgeValue += _pairPledge.pledgedValue - nowPledgedValue;
    //                 sourceChainPledgeBalance[sourceChain].set(pledgedToken, _pairPledge.pledgedValue);
    //             }
    //         }
    //         emit LogLPAction(_lp.pairId, lpId, lpData[lpId]);
    //         unchecked {
    //             ++i;
    //         }
    //     }
    //     if (needPledgeValue > 0) {
    //         uint256 unUsedAmount = idleAmount(pledgedToken);
    //         uint256 pledgedTokenValue = this.getPledgeBalance(pledgedToken);
    //         pledgeBalance.set(pledgedToken, pledgedTokenValue + needPledgeValue);
    //         if (needPledgeValue > unUsedAmount) {
    //             uint256 subunUsedAmount = needPledgeValue - unUsedAmount;
    //             if (pledgedToken == address(0)) {
    //                 require(msg.value >= subunUsedAmount, "Insufficient pledge quantity");
    //             } else {
    //                 if (needPledgeValue > 0) {
    //                     uint256 allowance = IERC20(pledgedToken).allowance(msg.sender, address(this));
    //                     require(allowance >= subunUsedAmount, "Token Insufficient pledge quantity");
    //                     bool success = IERC20(pledgedToken).transferFrom(msg.sender, address(this), subunUsedAmount);
    //                     require(success, "TransferFrom Fail");
    //                 }
    //             }
    //         }
    //     }
    // }

    // function lpPause(bytes32 pairId) external onlyOwner {
    //     IORManager manager = getManager();
    //     OperationsLib.EffectivePairStruct storage effectivePairItem = effectivePair[pairId];
    //     require(effectivePairItem.lpId != 0, "LP does not exist");
    //     require(effectivePairItem.startTime != 0 && effectivePairItem.stopTime == 0, "LP not started");
    //     (,uint256 sourceChain, , , ) = manager.getPairs(pairId);
    //     (, , , , uint256 stopDelayTime, ) = manager.getChain(sourceChain);
    //     effectivePairItem.stopTime = block.timestamp + stopDelayTime;
    //     effectivePairItem.startTime = 0;
    //     // emit LogLPPause(pairId, lpInfo[pairId].lpId, _lpinfo);
    // }

    // function lpRestart(bytes32 pairId) external onlyOwner {
    //     OperationsLib.EffectivePairStruct storage effectivePairItem = effectivePair[pairId];
    //     require(effectivePairItem.lpId != 0, "LP does not exist");
    //     require(effectivePairItem.startTime == 0 && effectivePairItem.stopTime != 0, "LP not paused");
    //     effectivePairItem.startTime = block.timestamp;
    //     effectivePairItem.stopTime = 0;
    // }

    // // LPStop
    // function lpStop(bytes32 pairId) external onlyOwner {
    //     IORManager manager = getManager();
    //     OperationsLib.EffectivePairStruct memory effectivePairItem = effectivePair[pairId];
    //     require(effectivePairItem.startTime == 0 && effectivePairItem.stopTime != 0, "LP not paused");
    //     require(block.timestamp >= effectivePairItem.stopTime, "Not yet operating time");
    //     OperationsLib.LPStruct storage lpInfo = lpData[effectivePairItem.lpId];
    //     (,uint256 sourceChain, , address sourceToken, ) = manager.getPairs(pairId);
    //     (, uint256 nowPairPledgedValue) = sourceChainPairs[sourceChain].tryGet(pairId);
    //     bool success = sourceChainPairs[sourceChain].remove(pairId);
    //     lpInfo.stopTime = block.timestamp;
    //     delete effectivePair[pairId];
    //     OperationsLib.TokenInfo memory tokenInfo = manager.getTokenInfo(sourceChain, sourceToken);
    //     address pledgedToken = tokenInfo.mainnetToken;
    //     uint256 nowSourceChainPledgedValue = this.getPledgeBalanceByChainToken(sourceChain, pledgedToken);
    //     if (nowPairPledgedValue == nowSourceChainPledgedValue) {
    //         // find max
    //         uint256 pledgedValue;
    //         for (uint256 i = 0; i < sourceChainPairs[sourceChain].length(); ) {
    //             (, uint256 value) = sourceChainPairs[sourceChain].at(i);
    //             pledgedValue = value > pledgedValue ? value : pledgedValue;
    //             unchecked {
    //                 ++i;
    //             }
    //         }
    //         uint256 subValue = nowSourceChainPledgedValue - pledgedValue;
    //         if (subValue > 0) {
    //             sourceChainPledgeBalance[sourceChain].set(pledgedToken, nowSourceChainPledgedValue - subValue);
    //             pledgeBalance.set(pledgedToken, nowSourceChainPledgedValue - subValue);
    //         }
    //     }
    // }

    // // LPUpdate
    // function lpUpdate(OperationsLib.LPUpdateStruct calldata _lp) external onlyOwner {
    //     bytes32 pairId = _lp.pairId;
    //     OperationsLib.EffectivePairStruct storage effectivePairItem = effectivePair[pairId];
    //     require(effectivePairItem.lpId != 0, "LP does not exist");
    //     require(effectivePairItem.startTime == 0 && effectivePairItem.stopTime != 0, "LP not paused");
    //     effectivePairItem.startTime = block.timestamp;
    //     effectivePairItem.stopTime = 0;
    //     // change old lp stop time
    //     OperationsLib.LPStruct storage lpInfo = lpData[effectivePairItem.lpId];
    //     lpInfo.stopTime = block.timestamp;
    //     // new lp
    //     bytes32 lpId = OperationsLib.getLpID(pairId, address(this), block.timestamp, lpInfo.minPrice, lpInfo.maxPrice);
    //     lpData[lpId] = OperationsLib.LPStruct(
    //         pairId,
    //         lpInfo.minPrice,
    //         lpInfo.maxPrice,
    //         _lp.gasFee,
    //         _lp.tradingFee,
    //         block.timestamp,
    //         0
    //     );
    //     effectivePair[pairId] = OperationsLib.EffectivePairStruct(lpId, block.timestamp, 0);
    // }

    // function lpUserStop(bytes32 pairId) internal {
    //     IORManager manager = getManager();
    //     (uint ebcId,uint256 sourceChain, , address sourceToken, ) = manager.getPairs(pairId);
    //     require(ebcId != 0, "USER_LPStop_EBCADDRESS_0");
    //     OperationsLib.TokenInfo memory tokenInfo = manager.getTokenInfo(sourceChain, sourceToken);
    //     address pledgedToken = tokenInfo.mainnetToken;
    //     (, , , , uint256 stopDelayTime, ) = manager.getChain(sourceChain);
    //     uint256 sourceChainPairsLength = sourceChainPairs[sourceChain].length();
    //     if (sourceChainPairsLength > 0) {
    //         bytes32[] memory pairs = new bytes32[](sourceChainPairsLength);
    //         // get all pairs by sourceChain
    //         for (uint256 pairIndex = 0; pairIndex < sourceChainPairsLength; ) {
    //             (bytes32 pair, ) = sourceChainPairs[sourceChain].at(pairIndex);
    //             pairs[pairIndex] = pair;
    //             unchecked {
    //                 ++pairIndex;
    //             }
    //         }
    //         for (uint256 i = 0; i < pairs.length; ) {
    //             bytes32 _pairId = pairs[i];
    //             require(sourceChainPairs[sourceChain].contains(_pairId), "Pair does not exist");
    //             bool success = sourceChainPairs[sourceChain].remove(_pairId);
    //             require(success, "Remove chainPairs Fail");
    //             OperationsLib.EffectivePairStruct memory effectivePairItem = effectivePair[_pairId];
    //             OperationsLib.LPStruct storage lpInfo = lpData[effectivePairItem.lpId];
    //             lpInfo.startTime = 0;
    //             lpInfo.stopTime = 0;
    //             delete effectivePair[_pairId];
    //             emit LogLPUserStop(pairs[i], effectivePairItem.lpId);
    //             unchecked {
    //                 ++i;
    //             }
    //         }
    //         uint256 pledgedTokenValue = this.getPledgeBalanceByChainToken(sourceChain, pledgedToken);
    //         // Release all deposits
    //         bool removed = sourceChainPledgeBalance[sourceChain].remove(pledgedToken);
    //         require(removed, "Remove chainPledgeBalance Fail");
    //         (, uint256 pledgedValue) = pledgeBalance.tryGet(pledgedToken);
    //         bool created = pledgeBalance.set(pledgedToken, pledgedValue - pledgedTokenValue);
    //         require(!created, "PledgeBalance Not Exist");
    //     }
    //     //Set Maker withdrawal time to the current time plus stopDelayTime.
    //     pledgeTokenLPStopDealyTime[pledgedToken] = block.timestamp + stopDelayTime;
    // }

    // // withDrawAssert()
    // function withDrawAssert(uint256 amount, address tokenAddress) external onlyOwner {
    //     // This condition is not passed only when the user withdrawals trigger a forced stop event.
    //     require(block.timestamp >= pledgeTokenLPStopDealyTime[tokenAddress], "WITHDRAW_NOTIME");
    //     require(amount != 0, "WITHDRAW_ILLEGALAMOUNT");
    //     require(challengePleged == 0, "WITHDRAW_NOCHANLLENGE");
    //     uint256 unUsedAmount = idleAmount(tokenAddress);
    //     require(amount <= unUsedAmount, "WITHDRAW_INSUFFICIENT_AMOUNT");
    //     // Cancellation of Maker withdrawal time limit
    //     if (pledgeTokenLPStopDealyTime[tokenAddress] != 0) {
    //         pledgeTokenLPStopDealyTime[tokenAddress] = 0;
    //     }
    //     if (tokenAddress != address(0)) {
    //         bool success = IERC20(tokenAddress).transfer(msg.sender, amount);
    //         require(success, "TransferFrom Fail");
    //     } else {
    //         payable(msg.sender).transfer(amount);
    //         // require(success, "TransferFrom Fail");
    //     }
    // }

    // function checkTxProofExists(bytes calldata validateBytes) internal view returns (OperationsLib.Transaction memory) {
    //     IORProventh spv = IORProventh(address(0));
    //     // TODO: get .getSPV
    //     return spv.startValidate(validateBytes);
    // }

    // // OperationsLib.ValidateParams result =
    // // userChallenge
    // // User Initiates Arbitration Request
    // function userChallenge(bytes calldata userTxBytes) external payable {
    //     OperationsLib.Transaction memory _txinfo = checkTxProofExists(userTxBytes);
    //     // Todo Temporary use
    //     IORManager manager = getManager();
    //     // TODO:
    //     address ebcAddress = manager.getEBCAddress(0);

    //     // Todo dev: Comment out the following two lines(require(xxx)) of code for testing

    //     // Determine whether sourceAddress in txinfo is consistent with the caller's address
    //     require(_txinfo.from == msg.sender, "UCE_SENDER");
    //     // Determine whether destAddress in txinfo is an MDC address
    //     require(_txinfo.to == owner, "UCE_4");

    //     // Verify whether it is within the period of appeal
    //     (, , , uint256 maxReceiptTime, , ) = getManager().getChain(_txinfo.chainId);

    //     require(block.timestamp > _txinfo.timeStamp + maxReceiptTime, "UCE_5");
    //     // txinfo and txproof are provided to EBC and verified to pass
    //     // Get the corresponding challengeID through txinfo.
    //     bytes32 challengeID = OperationsLib.getChallengeID(_txinfo);
    //     // The corresponding challengeInfo is required to be in an unused state.
    //     require(challengeInfos[challengeID].challengeState == 0, "UCE_USED");
    //     // The pledge required to be transferred by the user is greater than that stipulated in the EBC contract.
    //     require(IORProtocal(ebcAddress).checkUserChallenge(msg.value), "checkUserChallenge Fail");

    //     challengeInfos[challengeID].responseTxinfo = IORProtocal(ebcAddress).getResponseHash(_txinfo, true);
    //     challengeInfos[challengeID].pledged = msg.value;
    //     challengeInfos[challengeID].token = _txinfo.tokenAddress;
    //     challengeInfos[challengeID].value = _txinfo.value;
    //     challengeInfos[challengeID].ebc = ebcAddress;
    //     // Change the corresponding challengeInfos state to waiting for maker
    //     challengeInfos[challengeID].challengeState = 1;
    //     // challengeInfos's stopTime is the current time plus the maxDisputeTime.
    //     (, , uint256 maxDisputeTime, , , ) = getManager().getChain(_txinfo.chainId);
    //     challengeInfos[challengeID].stopTime = block.timestamp + maxDisputeTime;
    //     challengeInfos[challengeID].endTime = block.timestamp + maxDisputeTime + maxDisputeTime;

    //     // The pledge transferred by the user is included in the total pledge.
    //     challengePleged += msg.value;
    //     emit LogChallengeInfo(address(getMakerFactory), challengeID, challengeInfos[challengeID], _txinfo);
    // }

    // // userWithDraw
    // function userWithDraw(OperationsLib.Transaction calldata _userTx, OperationsLib.LPStruct calldata _lp) external {
    //     bytes32 challengeID = OperationsLib.getChallengeID(_userTx);
    //     // When the state of challengeInfos is 'waiting for maker' and the stopTime of challengeInfos has passed, the user can withdraw money.
    //     // Todo  dev: Comment out the following two lines(require(xxx)) of code for testing
    //     require(_userTx.from == msg.sender, "UW_SENDER");
    //     OperationsLib.challengeInfo storage challengeInfo = challengeInfos[challengeID];
    //     require(challengeInfo.challengeState == 1, "UW_WITHDRAW");
    //     require(block.timestamp > challengeInfo.stopTime, "UW_TIME");
    //     address ebcAddress = challengeInfo.ebc;
    //     require(ebcAddress != address(0), "UW_EBCADDRESS_0");
    //     // Get the unUsed balance corresponding to tokenAddress.
    //     uint256 unUsedAmount = idleAmount(challengeInfo.token);
    //     // Calculate the penalty (paid at a specific rate of principal)
    //     (uint256 baseValue, uint256 additiveValue) = IORProtocal(ebcAddress).calculateCompensation(
    //         challengeInfo.token,
    //         challengeInfo.value
    //     );
    //     uint256 withDrawAmount = baseValue + additiveValue;
    //     // When withDrawAmount is greater than unUsedAmount, it indicates that the available funds are insufficient and will trigger the mandatory stop of all LPs with sourceChain as lpinfo.sourceChain.
    //     challengeInfo.endTime = block.timestamp;
    //     challengeInfo.challengeState = 3;

    //     uint256 pledgeAmount = challengeInfo.pledged;
    //     require(challengePleged >= pledgeAmount, "ChallengePleged Insufficient balance");
    //     challengePleged -= pledgeAmount;
    //     emit LogChallengerCompensation(
    //         address(getMakerFactory),
    //         challengeID,
    //         baseValue,
    //         challengeInfo.pledged,
    //         additiveValue
    //     );
    //     // Subtract the pledge money transferred by the user challenge from the total pledge money.
    //     if (challengeInfo.token != address(0)) {
    //         if (withDrawAmount > unUsedAmount) {
    //             lpUserStop(_lp.pairId);
    //             idleAmount(challengeInfo.token);
    //         }
    //         bool success = IERC20(challengeInfo.token).transfer(msg.sender, withDrawAmount);
    //         require(success, "ERC20 Transfer Fail");
    //         require(address(this).balance >= pledgeAmount, "Insufficient balance");
    //         payable(msg.sender).transfer(pledgeAmount);
    //     } else {
    //         uint256 totalValue = withDrawAmount + pledgeAmount;
    //         if (totalValue > unUsedAmount) {
    //             lpUserStop(_lp.pairId);
    //         }
    //         require(address(this).balance >= totalValue, "Insufficient balance");
    //         payable(msg.sender).transfer(totalValue);
    //     }
    // }

    // // makerChllenger MakeGood
    // function challengerMakeGood(OperationsLib.Transaction calldata _userTx) external onlyOwner {
    //     // Get the corresponding challengeID through txinfo.
    //     bytes32 challengeID = OperationsLib.getChallengeID(_userTx);
    //     require(challengeInfos[challengeID].challengeState == 1, "MC_ANSWER");
    //     require(block.timestamp > challengeInfos[challengeID].endTime, "UW_TIME");
    //     challengeInfos[challengeID].challengeState = 3;

    //     OperationsLib.challengeInfo storage challengeInfo = challengeInfos[challengeID];
    //     address ebcAddress = challengeInfo.ebc;
    //     require(ebcAddress != address(0), "UW_EBCADDRESS_0");
    //     // Get the unUsed balance corresponding to tokenAddress.
    //     uint256 unUsedAmount = idleAmount(challengeInfo.token);
    //     // Calculate the penalty (paid at a specific rate of principal)
    //     (uint256 baseValue, uint256 additiveValue) = IORProtocal(ebcAddress).calculateCompensation(
    //         challengeInfo.token,
    //         challengeInfo.value
    //     );
    //     uint256 withDrawAmount = baseValue + additiveValue;
    //     // When withDrawAmount is greater than unUsedAmount, it indicates that the available funds are insufficient and will trigger the mandatory stop of all LPs with sourceChain as lpinfo.sourceChain.
    //     challengeInfo.endTime = block.timestamp;
    //     challengeInfo.challengeState = 4;
    //     // uint256 pledgeAmount = challengeInfo.pledged;
    //     require(challengePleged >= challengeInfo.pledged, "challengePleged Insufficient balance");
    //     challengePleged -= challengeInfo.pledged;
    //     // Subtract the pledge money transferred by the user challenge from the total pledge money.
    //     emit LogChallengerCompensation(
    //         address(getMakerFactory),
    //         challengeID,
    //         baseValue,
    //         challengeInfo.pledged,
    //         additiveValue
    //     );
    //     if (challengeInfo.token != address(0)) {
    //         require(unUsedAmount >= withDrawAmount, "Insufficient balance");
    //         bool success = IERC20(challengeInfo.token).transfer(_userTx.from, withDrawAmount);
    //         require(success, "ERC20 Transfer Fail");
    //         require(address(this).balance >= challengeInfo.pledged, "Insufficient balance");
    //         payable(_userTx.from).transfer(challengeInfo.pledged);
    //     } else {
    //         uint256 totalValue = withDrawAmount + challengeInfo.pledged;
    //         require(unUsedAmount >= totalValue, "Insufficient balance");
    //         require(address(this).balance >= totalValue, "Insufficient balance");
    //         payable(_userTx.from).transfer(totalValue);
    //     }
    // }

    // // maker responds to arbitration request
    // function makerChallenge(OperationsLib.Transaction calldata _userTx, bytes calldata makerTxBytes)
    //     external
    //     onlyOwner
    // {
    //     OperationsLib.Transaction memory _makerTx = checkTxProofExists(makerTxBytes);
    //     // Get the corresponding challengeID through txinfo.
    //     bytes32 challengeID = OperationsLib.getChallengeID(_userTx);
    //     // The corresponding challengeInfo is required to be in a waiting for maker state.
    //     require(challengeInfos[challengeID].challengeState == 1, "MC_ANSWER");
    //     // Change the corresponding challengeInfos state to maker success
    //     challengeInfos[challengeID].challengeState = 2;
    //     challengeInfos[challengeID].endTime = block.timestamp;
    //     // address ebcAddress = manager.getEBC(challengeInfos[challengeID].ebcid);
    //     address ebcAddress = challengeInfos[challengeID].ebc;
    //     // Determine whether sourceAddress in txinfo is an MDC address

    //     // Todo dev: Comment out the following one lines(require(xxx)) of code for testing
    //     require(_makerTx.from == msg.sender, "MC_SENDER");

    //     // userTx,makerTx and makerProof are provided to EBC and verified to pass
    //     require(IORProtocal(ebcAddress).checkMakerChallenge(_userTx, _makerTx), "MC_ERROR");

    //     // Todo dev: makerResponse is officially used;makerResponseTest is used for testing
    //     bytes32 makerResponse = IORProtocal(ebcAddress).getResponseHash(_makerTx, false);

    //     // testing
    //     // uint256 fromNonce = IORProtocal(ebcAddress).getToTxNonceId(_makerTx);
    //     // uint256 responseAmount = IORProtocal(ebcAddress).getResponseAmount(_userTx);
    //     // bytes32 makerResponseTest = keccak256(
    //     //     abi.encodePacked(_makerTx.to, _makerTx.from, uint256(_makerTx.chainId), fromNonce, responseAmount)
    //     // );

    //     // The proof of validity of userTx is required to be consistent with that of makerTx.
    //     require(challengeInfos[challengeID].responseTxinfo == makerResponse, "MCE_UNMATCH");
    //     // Subtract the pledge money transferred by the user challenge from the total pledge money.
    //     challengePleged -= challengeInfos[challengeID].pledged;
    //     emit LogChallengeInfo(address(this), challengeID, challengeInfos[challengeID], _makerTx);
    // }

    // receive() external payable {
    //     emit Deposit(msg.sender, msg.value);
    // }
}
