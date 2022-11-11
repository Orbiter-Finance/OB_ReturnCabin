# Solidity API

## ORMakerDeposit

### makerFactory

```solidity
address makerFactory
```

### lpInfo

```solidity
mapping(bytes32 => struct OperationsLib.lpPairInfo) lpInfo
```

### chainDeposit

```solidity
mapping(uint256 => mapping(address => struct OperationsLib.chainDeposit)) chainDeposit
```

### chanllengeInfos

```solidity
mapping(bytes32 => struct OperationsLib.chanllengeInfo) chanllengeInfos
```

### usedDeposit

```solidity
mapping(address => uint256) usedDeposit
```

### USER_LPStopDelayTime

```solidity
mapping(address => uint256) USER_LPStopDelayTime
```

### chanllengePleged

```solidity
uint256 chanllengePleged
```

### initialize

```solidity
function initialize(address _owner, address _makerFactory) public
```

### getManagerAddress

```solidity
function getManagerAddress() internal view returns (address)
```

### getEBCAddress

```solidity
function getEBCAddress(uint256 ebcid) internal view returns (address)
```

### getChainInfoByChainID

```solidity
function getChainInfoByChainID(uint256 chainId) internal view returns (struct OperationsLib.chainInfo)
```

### idleAmount

```solidity
function idleAmount(address tokenAddress) public view returns (uint256)
```

### getDepositTokenInfo

```solidity
function getDepositTokenInfo(struct OperationsLib.lpInfo _lpinfo) internal view returns (struct OperationsLib.tokenInfo)
```

### getChainDepositInfo

```solidity
function getChainDepositInfo(struct OperationsLib.lpInfo _lpinfo) internal view returns (struct OperationsLib.chainDeposit)
```

### getSpvAddress

```solidity
function getSpvAddress() internal view returns (address)
```

### LPAction

```solidity
function LPAction(struct OperationsLib.lpInfo[] _lpinfos, bytes32[][] pairProof) external payable
```

### LPPause

```solidity
function LPPause(struct OperationsLib.lpInfo[] _lpinfos) external
```

### LPStop

```solidity
function LPStop(struct OperationsLib.lpInfo[] _lpinfos) external
```

### LPUpdate

```solidity
function LPUpdate(struct OperationsLib.changeLP[] _lpinfos) external
```

### withDrawAssert

```solidity
function withDrawAssert(uint256 amount, address tokenAddress) external
```

### userChanllenge

```solidity
function userChanllenge(struct OperationsLib.txInfo _txinfo, bytes32[] _txproof) external payable
```

### USER_LPStop

```solidity
function USER_LPStop(uint256 sourceChain, address tokenAddress, uint256 ebcid) internal
```

### userWithDraw

```solidity
function userWithDraw(struct OperationsLib.txInfo _userTx, struct OperationsLib.lpInfo _lpinfo) external
```

### makerChanllenger

```solidity
function makerChanllenger(struct OperationsLib.txInfo _userTx, struct OperationsLib.txInfo _makerTx, bytes32[] _makerProof) external
```

## ORMakerV1Factory

### manager

```solidity
address manager
```

### getMaker

```solidity
mapping(address => address) getMaker
```

### initialize

```solidity
function initialize(address _manager) public
```

### setManager

```solidity
function setManager(address value) external
```

### getManager

```solidity
function getManager() external view returns (address)
```

### createMaker

```solidity
function createMaker() external returns (address pool)
```

## ORManager

### ebcPair

```solidity
mapping(uint256 => address) ebcPair
```

### chainList

```solidity
mapping(uint256 => struct OperationsLib.chainInfo) chainList
```

### tokenInfos

```solidity
mapping(uint256 => mapping(address => struct OperationsLib.tokenInfo)) tokenInfos
```

### ebcids

```solidity
uint256 ebcids
```

### pairsRoot

```solidity
bytes32 pairsRoot
```

### spv

```solidity
address spv
```

### initialize

```solidity
function initialize() public
```

### getEBCids

```solidity
function getEBCids() external view returns (uint256)
```

### setSPV

```solidity
function setSPV(address spvAddress) external returns (bool)
```

### getSPV

```solidity
function getSPV() external view returns (address)
```

### setEBC

```solidity
function setEBC(address ebcAddress) external returns (bool)
```

### updateEBC

```solidity
function updateEBC(uint256 ebcid, address ebcAddress) external
```

### getEBC

```solidity
function getEBC(uint256 ebcid) external view returns (address)
```

### setChainInfo

```solidity
function setChainInfo(uint256 chainID, uint256 batchLimit, uint256 maxDisputeTime, uint256 maxReceiptTime, address[] tokenList) external
```

### getChainInfoByChainID

```solidity
function getChainInfoByChainID(uint256 chainID) public view returns (struct OperationsLib.chainInfo)
```

### setTokenInfo

```solidity
function setTokenInfo(uint256 chainID, address tokenAddress, uint256 tokenPresion, address mainAddress) external
```

### getTokenInfo

```solidity
function getTokenInfo(uint256 chainID, address tokenAddress) external view returns (struct OperationsLib.tokenInfo)
```

### isSupportChain

```solidity
function isSupportChain(uint256 chainID, address token) public view returns (bool)
```

### createPair

```solidity
function createPair(struct OperationsLib.pairChainInfo[] pairs, bytes32 rootHash, bytes32[] proof, bool[] proofFlags) external
```

### deletePair

```solidity
function deletePair(struct OperationsLib.pairChainInfo[] pairs, bytes32[] proof, bool[] proofFlags, bytes32 rootHash) external
```

### isSupportPair

```solidity
function isSupportPair(bytes32 pair, bytes32[] proof) public view returns (bool)
```

### isSupportPair

```solidity
function isSupportPair(struct OperationsLib.pairChainInfo pair, bytes32[] proof) public view returns (bool)
```

### pairObjectToHash

```solidity
function pairObjectToHash(struct OperationsLib.pairChainInfo[] pairs) internal pure returns (bytes32[])
```

### pairMultiProofVerifyCalldata

```solidity
function pairMultiProofVerifyCalldata(struct OperationsLib.pairChainInfo[] pairs, bytes32 root, bytes32[] proof, bool[] proofFlags) internal pure returns (bool isSupport)
```

## ORProtocalV1

### _managerAddress

```solidity
address _managerAddress
```

### ChanllengePledgeAmountCoefficient

```solidity
uint256 ChanllengePledgeAmountCoefficient
```

### DepositAmountCoefficient

```solidity
uint256 DepositAmountCoefficient
```

### EthPunishCoefficient

```solidity
uint256 EthPunishCoefficient
```

### TokenPunishCoefficient

```solidity
uint256 TokenPunishCoefficient
```

### PauseAfterStopInterval

```solidity
uint32 PauseAfterStopInterval
```

### ChangeLpEffectInterval

```solidity
uint32 ChangeLpEffectInterval
```

### initialize

```solidity
function initialize(address managerAddress, uint256 _chanllengePledgeAmountCoefficient, uint256 _depositAmountCoefficient, uint256 _ethPunishCoefficient, uint256 _tokenPunishCoefficie, uint32 _pauseAfterStopInterval) public
```

### setPauseAfterStopInterval

```solidity
function setPauseAfterStopInterval(uint32 value) external
```

### getPauseAfterStopInterval

```solidity
function getPauseAfterStopInterval() external view returns (uint256)
```

### getChangeLpAfterEffectInterval

```solidity
function getChangeLpAfterEffectInterval() external view returns (uint256)
```

### setChangeLpAfterEffectInterval

```solidity
function setChangeLpAfterEffectInterval(uint32 value) external
```

### setChanllengePledgeAmountCoefficient

```solidity
function setChanllengePledgeAmountCoefficient(uint256 _wei) external
```

### getChanllengePledgeAmountCoefficient

```solidity
function getChanllengePledgeAmountCoefficient() external view returns (uint256)
```

### setDepositAmountCoefficient

```solidity
function setDepositAmountCoefficient(uint256 hundredDigits) external
```

### getDepositAmountCoefficient

```solidity
function getDepositAmountCoefficient() external view returns (uint256)
```

### setETHPunishCoefficient

```solidity
function setETHPunishCoefficient(uint256 hundredDigits) external
```

### getETHPunishCoefficient

```solidity
function getETHPunishCoefficient() external view returns (uint256)
```

### setTokenPunishCoefficient

```solidity
function setTokenPunishCoefficient(uint256 hundredDigits) external
```

### getTokenPunishCoefficient

```solidity
function getTokenPunishCoefficient() external view returns (uint256)
```

### getDepositAmount

```solidity
function getDepositAmount(uint256 batchLimit, uint256 maxPrice) external view returns (uint256)
```

### getETHPunish

```solidity
function getETHPunish(uint256 amount) external view returns (uint256)
```

### getTokenPunish

```solidity
function getTokenPunish(uint256 amount) external view returns (uint256)
```

### getStartDealyTime

```solidity
function getStartDealyTime(uint256 chainID) external pure returns (uint256)
```

### getStopDealyTime

```solidity
function getStopDealyTime(uint256 chainID) external view returns (uint256)
```

### getSecuirtyCode

```solidity
function getSecuirtyCode(bool isSource, uint256 amount) public pure returns (uint256, bool)
```

### getRespnseHash

```solidity
function getRespnseHash(struct OperationsLib.txInfo _txinfo) external pure returns (bytes32)
```

### checkUserChallenge

```solidity
function checkUserChallenge(struct OperationsLib.txInfo _txinfo, bytes32[] _txproof) external view returns (bool)
```

### checkMakerChallenge

```solidity
function checkMakerChallenge(struct OperationsLib.txInfo _userTx, struct OperationsLib.txInfo _makerTx, bytes32[] _makerProof) external view returns (bool)
```

### maxWithdrawTime

```solidity
function maxWithdrawTime() external pure returns (uint256)
```

### getSpvAddress

```solidity
function getSpvAddress() internal view returns (address)
```

## ORSpv

SPV proves that Source Tx has occurred in the Source Network.

### makerTxTree

```solidity
mapping(uint256 => bytes32) makerTxTree
```

### userTxTree

```solidity
mapping(uint256 => bytes32) userTxTree
```

### initialize

```solidity
function initialize() public
```

### setUserTxTreeRoot

```solidity
function setUserTxTreeRoot(uint256 chain, bytes32 root) external
```

Set new transaction tree root hash

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| chain | uint256 | Public chain ID |
| root | bytes32 | New root hash |

### setMakerTxTreeRoot

```solidity
function setMakerTxTreeRoot(uint256 chain, bytes32 root) external
```

Set the list of transactions for the market maker to delay payment collection roothash

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| chain | uint256 | Public chain ID |
| root | bytes32 | New root hash |

### getSpvTxId

```solidity
function getSpvTxId(struct OperationsLib.txInfo _txInfo) internal pure returns (bytes32)
```

### verifyUserTxProof

```solidity
function verifyUserTxProof(struct OperationsLib.txInfo _txInfo, bytes32[] _proof) public view returns (bool)
```

Transaction list of unpaid users

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _txInfo | struct OperationsLib.txInfo | User transaction object |
| _proof | bytes32[] | Transaction proof path |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | Exist or fail to verify |

### verifyMakerTxProof

```solidity
function verifyMakerTxProof(struct OperationsLib.txInfo _txInfo, bytes32[] _proof) public view returns (bool)
```

List of merchant transactions with delayed payment

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _txInfo | struct OperationsLib.txInfo | User transaction object |
| _proof | bytes32[] | Transaction proof path |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | Exist or fail to verify |

### verify

```solidity
function verify(bytes32 root, bytes32 leaf, bytes32[] proof) internal pure returns (bool)
```

Validation exists in the merkle tree

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| root | bytes32 | This root will be compared to the calculated root |
| leaf | bytes32 | Leaf nodes that need proof |
| proof | bytes32[] | Provide proof path |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | true or false |

## IERC20

_Interface of the ERC20 standard as defined in the EIP. Does not include
the optional functions; to access them see {ERC20Detailed}._

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```

_Returns the amount of tokens in existence._

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```

_Returns the amount of tokens owned by `account`._

### transfer

```solidity
function transfer(address recipient, uint256 amount) external returns (bool)
```

_Moves `amount` tokens from the caller's account to `recipient`.

Returns a boolean value indicating whether the operation succeeded.

Emits a {Transfer} event._

### allowance

```solidity
function allowance(address owner, address spender) external view returns (uint256)
```

_Returns the remaining number of tokens that `spender` will be
allowed to spend on behalf of `owner` through {transferFrom}. This is
zero by default.

This value changes when {approve} or {transferFrom} are called._

### approve

```solidity
function approve(address spender, uint256 amount) external returns (bool)
```

_Sets `amount` as the allowance of `spender` over the caller's tokens.

Returns a boolean value indicating whether the operation succeeded.

IMPORTANT: Beware that changing an allowance with this method brings the risk
that someone may use both the old and the new allowance by unfortunate
transaction ordering. One possible solution to mitigate this race
condition is to first reduce the spender's allowance to 0 and set the
desired value afterwards:
https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729

Emits an {Approval} event._

### transferFrom

```solidity
function transferFrom(address sender, address recipient, uint256 amount) external returns (bool)
```

_Moves `amount` tokens from `sender` to `recipient` using the
allowance mechanism. `amount` is then deducted from the caller's
allowance.

Returns a boolean value indicating whether the operation succeeded.

Emits a {Transfer} event._

### Transfer

```solidity
event Transfer(address from, address to, uint256 value)
```

_Emitted when `value` tokens are moved from one account (`from`) to
another (`to`).

Note that `value` may be zero._

### Approval

```solidity
event Approval(address owner, address spender, uint256 value)
```

_Emitted when the allowance of a `spender` for an `owner` is set by
a call to {approve}. `value` is the new allowance._

## IORMakerDeposit

### lpState

```solidity
enum lpState {
  ACTION,
  UPDATE,
  PAUSE,
  STOP,
  USERSTOP
}
```

### chanllengeState

```solidity
enum chanllengeState {
  ACTION,
  RESPONSED,
  WITHDRAWED
}
```

### LogLPStop

```solidity
event LogLPStop(bytes32 pairId, bytes32 lpId)
```

### ChainDepositChange

```solidity
event ChainDepositChange(address makerId, address token, uint256 amount, uint256 useLimit, bytes32[] pairs)
```

### LogLpInfo

```solidity
event LogLpInfo(bytes32 pairId, bytes32 lpId, enum IORMakerDeposit.lpState state, struct OperationsLib.lpInfo lpinfo)
```

### LogChanllengeInfo

```solidity
event LogChanllengeInfo(uint256 chainId, enum IORMakerDeposit.chanllengeState opType, bytes32 chanllengeId, struct OperationsLib.txInfo txInfo, struct OperationsLib.chanllengeInfo chanllenge)
```

### MakerChangeLP

```solidity
event MakerChangeLP(bytes32 pairId, bytes32 lpId, uint256 startTime, uint256 gasFee, uint256 tradingFee)
```

### idleAmount

```solidity
function idleAmount(address tokenAddress) external view returns (uint256)
```

### LPAction

```solidity
function LPAction(struct OperationsLib.lpInfo[] _lpinfos, bytes32[][] pairProof) external payable
```

### LPPause

```solidity
function LPPause(struct OperationsLib.lpInfo[] _lpinfos) external
```

### LPStop

```solidity
function LPStop(struct OperationsLib.lpInfo[] _lpinfos) external
```

### LPUpdate

```solidity
function LPUpdate(struct OperationsLib.changeLP[] _lpinfos) external
```

### withDrawAssert

```solidity
function withDrawAssert(uint256, address) external
```

### userChanllenge

```solidity
function userChanllenge(struct OperationsLib.txInfo, bytes32[]) external payable
```

### userWithDraw

```solidity
function userWithDraw(struct OperationsLib.txInfo, struct OperationsLib.lpInfo) external
```

### makerChanllenger

```solidity
function makerChanllenger(struct OperationsLib.txInfo, struct OperationsLib.txInfo, bytes32[]) external
```

## IORMakerV1Factory

### MakerCreated

```solidity
event MakerCreated(address maker, address pool)
```

### initialize

```solidity
function initialize(address) external
```

### createMaker

```solidity
function createMaker() external returns (address)
```

### setManager

```solidity
function setManager(address) external
```

### getManager

```solidity
function getManager() external view returns (address)
```

## IORManager

### PairEventType

```solidity
enum PairEventType {
  CREATE,
  DELETE
}
```

### PairLogEvent

```solidity
event PairLogEvent(enum IORManager.PairEventType opType, struct OperationsLib.pairChainInfo[] pairs)
```

### ChangeChain

```solidity
event ChangeChain(uint256 chainId, struct OperationsLib.chainInfo chain)
```

### ChangeToken

```solidity
event ChangeToken(uint256 chainId, address tokenAddress, struct OperationsLib.tokenInfo token)
```

### setSPV

```solidity
function setSPV(address spvAddress) external returns (bool)
```

### getSPV

```solidity
function getSPV() external view returns (address)
```

### setEBC

```solidity
function setEBC(address ebcAddress) external returns (bool)
```

### getEBC

```solidity
function getEBC(uint256 ebcid) external view returns (address)
```

### updateEBC

```solidity
function updateEBC(uint256 ebcid, address ebcAddress) external
```

### setChainInfo

```solidity
function setChainInfo(uint256, uint256, uint256, uint256, address[]) external
```

### getChainInfoByChainID

```solidity
function getChainInfoByChainID(uint256 chainID) external view returns (struct OperationsLib.chainInfo)
```

### setTokenInfo

```solidity
function setTokenInfo(uint256, address, uint256, address) external
```

### getTokenInfo

```solidity
function getTokenInfo(uint256, address) external view returns (struct OperationsLib.tokenInfo)
```

### createPair

```solidity
function createPair(struct OperationsLib.pairChainInfo[] pairs, bytes32 rootHash, bytes32[] proof, bool[] proofFlags) external
```

### deletePair

```solidity
function deletePair(struct OperationsLib.pairChainInfo[] pairs, bytes32[] proof, bool[] proofFlags, bytes32 rootHash) external
```

### isSupportChain

```solidity
function isSupportChain(uint256 chainID, address token) external view returns (bool)
```

### isSupportPair

```solidity
function isSupportPair(bytes32 pair, bytes32[] proof) external view returns (bool)
```

### isSupportPair

```solidity
function isSupportPair(struct OperationsLib.pairChainInfo pair, bytes32[] proof) external view returns (bool)
```

## IORProtocal

### setChanllengePledgeAmountCoefficient

```solidity
function setChanllengePledgeAmountCoefficient(uint256 _wei) external
```

### getChanllengePledgeAmountCoefficient

```solidity
function getChanllengePledgeAmountCoefficient() external view returns (uint256)
```

### setDepositAmountCoefficient

```solidity
function setDepositAmountCoefficient(uint256 hundredDigits) external
```

### setPauseAfterStopInterval

```solidity
function setPauseAfterStopInterval(uint32 value) external
```

### getPauseAfterStopInterval

```solidity
function getPauseAfterStopInterval() external view returns (uint256)
```

### getChangeLpAfterEffectInterval

```solidity
function getChangeLpAfterEffectInterval() external view returns (uint256)
```

### setChangeLpAfterEffectInterval

```solidity
function setChangeLpAfterEffectInterval(uint32 value) external
```

### getDepositAmountCoefficient

```solidity
function getDepositAmountCoefficient() external view returns (uint256)
```

### setTokenPunishCoefficient

```solidity
function setTokenPunishCoefficient(uint256 hundredDigits) external
```

### getTokenPunishCoefficient

```solidity
function getTokenPunishCoefficient() external view returns (uint256)
```

### setETHPunishCoefficient

```solidity
function setETHPunishCoefficient(uint256 hundredDigits) external
```

### getETHPunishCoefficient

```solidity
function getETHPunishCoefficient() external view returns (uint256)
```

### getDepositAmount

```solidity
function getDepositAmount(uint256 batchLimit, uint256 maxPrice) external view returns (uint256)
```

### getTokenPunish

```solidity
function getTokenPunish(uint256 amount) external view returns (uint256)
```

### getETHPunish

```solidity
function getETHPunish(uint256 amount) external view returns (uint256)
```

### getStartDealyTime

```solidity
function getStartDealyTime(uint256 chainID) external view returns (uint256)
```

### getStopDealyTime

```solidity
function getStopDealyTime(uint256 chainID) external view returns (uint256)
```

### getSecuirtyCode

```solidity
function getSecuirtyCode(bool isSource, uint256 amount) external view returns (uint256, bool)
```

### getRespnseHash

```solidity
function getRespnseHash(struct OperationsLib.txInfo _txinfo) external pure returns (bytes32)
```

### checkUserChallenge

```solidity
function checkUserChallenge(struct OperationsLib.txInfo, bytes32[]) external view returns (bool)
```

### checkMakerChallenge

```solidity
function checkMakerChallenge(struct OperationsLib.txInfo, struct OperationsLib.txInfo, bytes32[]) external returns (bool)
```

### maxWithdrawTime

```solidity
function maxWithdrawTime() external view returns (uint256)
```

## IORSpv

### setUserTxTreeRoot

```solidity
function setUserTxTreeRoot(uint256 chain, bytes32 root) external
```

### setMakerTxTreeRoot

```solidity
function setMakerTxTreeRoot(uint256 chain, bytes32 root) external
```

### verifyUserTxProof

```solidity
function verifyUserTxProof(struct OperationsLib.txInfo _txInfo, bytes32[] _proof) external view returns (bool)
```

### verifyMakerTxProof

```solidity
function verifyMakerTxProof(struct OperationsLib.txInfo _txInfo, bytes32[] _proof) external view returns (bool)
```

## OperationsLib

### pairChainInfo

```solidity
struct pairChainInfo {
  uint256 sourceChain;
  uint256 destChain;
  address sourceTAddress;
  address destTAddress;
  uint256 ebcid;
}
```

### tokenInfo

```solidity
struct tokenInfo {
  uint256 chainID;
  address tokenAddress;
  uint256 tokenPresion;
  address mainTokenAddress;
}
```

### chainInfo

```solidity
struct chainInfo {
  uint256 chainid;
  uint256 batchLimit;
  uint256 maxDisputeTime;
  uint256 maxReceiptTime;
  address[] tokenList;
  bool isUsed;
}
```

### txInfo

```solidity
struct txInfo {
  uint256 chainID;
  bytes32 txHash;
  bytes32 lpid;
  address sourceAddress;
  address destAddress;
  address tokenAddress;
  uint256 amount;
  uint256 nonce;
  uint256 timestamp;
  uint256 responseAmount;
  uint256 responseSafetyCode;
  uint256 ebcid;
}
```

### lpInfo

```solidity
struct lpInfo {
  uint256 sourceChain;
  uint256 destChain;
  address sourceTAddress;
  address destTAddress;
  uint256 sourcePresion;
  uint256 destPresion;
  uint256 ebcid;
  uint256 minPrice;
  uint256 maxPrice;
  uint256 gasFee;
  uint256 tradingFee;
  uint256 startTime;
}
```

### changeLP

```solidity
struct changeLP {
  bytes32 pairId;
  bytes32 lpId;
  uint256 gasFee;
  uint256 tradingFee;
}
```

### lpPairInfo

```solidity
struct lpPairInfo {
  bytes32 lpId;
  uint256 stopTime;
  uint256 startTime;
}
```

### chainDeposit

```solidity
struct chainDeposit {
  address tokenAddress;
  uint256 depositAmount;
  uint256 useLimit;
  bytes32[] pairs;
}
```

### chanllengeInfo

```solidity
struct chanllengeInfo {
  uint256 chanllengeState;
  bytes32 responseTxinfo;
  uint256 stopTime;
  uint256 endTime;
  uint256 pledgeAmount;
  uint256 ebcid;
}
```

### getPairID

```solidity
function getPairID(struct OperationsLib.pairChainInfo _lpinfo) internal pure returns (bytes32)
```

### getPairID

```solidity
function getPairID(struct OperationsLib.lpInfo _lpinfo) internal pure returns (bytes32)
```

### getLpID

```solidity
function getLpID(address makerId, bytes32 pairId, uint256 startTime, uint256 gasFee, uint256 tradingFee) internal pure returns (bytes32)
```

### getChanllengeID

```solidity
function getChanllengeID(struct OperationsLib.txInfo _txinfo) internal pure returns (bytes32)
```

