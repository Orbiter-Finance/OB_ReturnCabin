// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "hardhat/console.sol";
import "./library/Type.sol";
// import "./interface/IMakerFactory.sol";
import "./interface/IManager.sol";
import "./interface/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

interface IMakerFactory {
    function manager() external view returns (IManager manager);
}

contract MakerDeposit {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;
    address public owner;
    IMakerFactory public makerFactory;
    mapping(bytes32 => Types.PairConfig) public pairs;
    mapping(uint8 => EnumerableMap.Bytes32ToUintMap) private pairsPledgeAmounts;
    mapping(address => uint256) public challengePledge;
    mapping(uint8 => EnumerableMap.AddressToUintMap) private pairPledgeByChainToken;
    EnumerableMap.AddressToUintMap private pairPledgeByToken;

    event Start(bytes32 indexed pairKey, Types.PairConfig config);
    event Update(bytes32 indexed pairKey, uint tradingFee, uint withholdingFee);

    function initialize() public {
        require(owner == address(0), "Already initialized");
        owner = tx.origin;
        makerFactory = IMakerFactory(msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function getManager() private view returns (IManager manager) {
        manager = makerFactory.manager();
    }

    function getPairPledgeByToken(address token) external view returns (uint256) {
        (, uint256 value) = pairPledgeByToken.tryGet(token);
        return value;
    }

    function getPairPledgeByChainToken(uint8 chainId, address token) external view returns (uint256) {
        (, uint256 value) = pairPledgeByChainToken[chainId].tryGet(token);
        return value;
    }

    function getIdleAmount(address token) public view returns (uint256) {
        uint256 balance = 0;
        if (token != address(0)) {
            IERC20 liquidityToken = IERC20(token);
            balance = liquidityToken.balanceOf(address(this));
        } else {
            balance = address(this).balance;
        }
        uint256 pledged = this.getPairPledgeByToken(token);
        uint256 idleamount = balance - pledged - challengePledge[token];
        return idleamount;
    }

    function checkStartPair(
        Types.Pair calldata _pair
    ) private view returns (bytes32 pairKey, uint sBatchLimit, address layer1Token) {
        IManager manager = getManager();
        uint8 sId;
        uint8 dId;
        {
            (sId, sBatchLimit) = manager.chains(_pair.s);
            require(sId == _pair.s, "SourceChain wrong");
        }
        {
            (dId, ) = manager.chains(_pair.d);
            require(dId == _pair.d, "DestChain wrong");
        }
        //
        Types.TokenInfo memory sToken = manager.getTokenInfo(sId, _pair.sToken);
        require(sToken.tokenAddress == _pair.sToken, "SToken wrong");
        Types.TokenInfo memory dToken = manager.getTokenInfo(dId, _pair.dToken);
        require(dToken.tokenAddress == _pair.dToken, "DToken wrong");

        layer1Token = sToken.layer1Token;
        // ok
        pairKey = keccak256(abi.encodePacked(sId, dId, sToken.tokenAddress, dToken.tokenAddress));
    }

    function start(
        Types.Pair calldata _pair,
        uint tradingFee,
        uint withholdingFee,
        uint minPrice,
        uint maxPrice
    ) external payable onlyOwner {
        require(tradingFee != 0, "Missing parameter tradingFee");
        require(withholdingFee != 0, "Missing parameter withholdingFee");
        require(minPrice != 0, "Missing parameter minPrice");
        require(maxPrice != 0, "Missing parameter maxPrice");
        // check s,d,stoken,dtoken support
        uint8 sId = _pair.s;
        (bytes32 pairKey, uint sBatchLimit, address layer1Token) = checkStartPair(_pair);
        require(pairs[pairKey].state == 0, "Pair Wrong state");
        // check new or change
        // Calculated to deposit
        // Verify if it has been pledged
        uint pledgeAmount = (sBatchLimit * maxPrice);
        uint nowPledgeAmount = this.getPairPledgeByChainToken(_pair.s, layer1Token);
        uint maxPledgeAmount = nowPledgeAmount;
        Types.PairConfig memory config = Types.PairConfig({
            state: 1,
            tradingFee: tradingFee,
            withholdingFee: withholdingFee,
            minPrice: minPrice,
            maxPrice: maxPrice
        });
        if (nowPledgeAmount <= pledgeAmount) {
            uint lack = pledgeAmount - nowPledgeAmount;
            if (lack > 0) {
                uint idleAmount = getIdleAmount(layer1Token);
                if (idleAmount < lack) {
                    if (layer1Token == address(0)) {
                        // main token
                        require(idleAmount >= pledgeAmount, "Insufficient idle funds for pledge");
                    } else {
                        // TODO: erc20 token
                        uint256 allowance = IERC20(layer1Token).allowance(msg.sender, address(this));
                        require(allowance >= lack, "Token Insufficient pledge quantity");
                        bool success = IERC20(layer1Token).transferFrom(msg.sender, address(this), lack);
                        require(success, "TransferFrom Fail");
                    }
                }
            }
            maxPledgeAmount = pledgeAmount;
        }
        {
            pairsPledgeAmounts[sId].set(pairKey, pledgeAmount);
            pairPledgeByChainToken[sId].set(layer1Token, maxPledgeAmount);
            pairPledgeByToken.set(layer1Token, maxPledgeAmount);
        }
        pairs[pairKey] = config;
        emit Start(pairKey, config);
    }

    function update(bytes32 pairKey, uint tradingFee, uint withholdingFee) external payable onlyOwner {
        require(pairs[pairKey].tradingFee != 0, "Missing parameter tradingFee");
        require(pairs[pairKey].withholdingFee != 0, "Missing parameter tradingFee");

        emit Update(pairKey, tradingFee, withholdingFee);
    }

    function getPairMaxPledgeValue(uint8 chainId) internal view returns (uint maxPledgeAmount) {
        for (uint i = 0; i < pairsPledgeAmounts[chainId].length(); i++) {
            (, uint value) = pairsPledgeAmounts[chainId].at(i);
            if (value > maxPledgeAmount) {
                maxPledgeAmount = value;
            }
        }
    }
    // function calculatePairPledgeAmount() {

    // }
}
