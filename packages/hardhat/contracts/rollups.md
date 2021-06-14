pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//import "@openzeppelin/contracts/access/Ownable.sol"; //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract rollup {
    // Merchant related data
    struct businessInfo {
        uint256 tokenAmount;
        uint256 tokenFee; // tokenFee / 10000
    }
    mapping(address => businessInfo) businessMember;
    mapping(address => bool) businessState;
    // Order related data
    struct orderInfo {
        address businessAddress;
        address customerAddress;
        address destinationAddress;
        uint256 orderID;
        uint256 orderFee;
        uint256 orderAmount;
        uint256 orderStatus;
    }

    //orderID => orderInfo
    mapping(uint256 => orderInfo) orderData;
    // Increment 1 to mark the number of orders
    uint256 orderID;
    // Order list Get every transaction through orderID
    orderInfo[] orderArray;
    // Token unlock and freeze related
    // Related evidence submitted by both parties

    // The address of the token contract supported by the contract
    address _tokenAddress = address(0x0);

    // owner
    address public owner;

    event registerToBusinessman(
        address business,
        uint256 tokenAmount,
        uint256 tokenFee
    );

    event unRegisterToBusinessman(address business);

    event placeAnOrder(
        address customer,
        address business,
        address destinationAddress,
        uint256 tokenAmount
    );

    constructor() {
        owner = msg.sender;
        // what should we do on deploy?
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function initTokenAddress(address tokenAddress) onlyOwner {
        require(
            tokenAddress != address(0),
            "tokenAddress can not be address(0)"
        );
        _tokenAddress = tokenAddress;
    }

    function placeAnOrder(
        address customer,
        address business,
        address destinationAddress,
        uint256 tokenAmount
    ) public {
        require(msg.sender == address(0x0), "1234");
        require(customer != address(0x0), "2345");
        require(business != address(0x0), "3456");
        require(destinationAddress != address(0x0), "3456");

        require(businessState[business] == true, "4567");

        require(businessMember[business].tokenAmount > tokenAmount, "5678");

        // order
        orderInfo memory newInfo =
            orderInfo(
                business,
                customer,
                destinationAddress,
                orderID,
                usinessMember[business].tokenFee,
                orderAmount,
                1
            );
        businessMember[business].tokenAmount -= tokenAmount;
        // map(orderID => orderInfo)  map(orderID =>??)
    }

    // register bussinessMan
    function registerToBusinessman(
        address business,
        uint256 tokenAmount,
        uint256 tokenFee
    ) public payable {
        // 1.business must be the initiator
        require(business == msg.sender, "msg.sender must be equal to business");
        require(tokenAddress != address(0x0), "tokenAddress must be init");

        // 2.Check if the address has enough tokens(eg erc20)
        tokenContract = ERC20(_tokenAddress);
        require(
            tokenContract.balanceof(business) >= tokenAmount,
            "business does not have enough tokens"
        );
        // 3.bussiness transfers tokenAmount tokens to the contract
        // ??????
        business.transfer(tokenAmount);
        // 4.businessMan Related information processing
        if (!businessState[business]) {
            businessState[business] = true;
            businessMember[business].tokenAmount = tokenAmount;
            businessMember[business].tokenFee = tokenFee;
        } else {
            businessState[business] = true;
            businessMember[business].tokenAmount += tokenAmount;
            businessMember[business].tokenFee = tokenFee;
        }
    }

    // unregister businessMan
    function unRegisterToBusinessman(address business) public payable {
        // 1.business must be the initiator
        require(business == msg.sender, "msg.sender must be equal to business");
        require(tokenAddress != address(0x0), "tokenAddress must be init");

        // 2.business must be businessman
        require(
            businessState[business] == true,
            "business is not a businessman"
        );

        // 3. The business must have remaining tokens
        require(
            businessMember[business].tokenAmount != 0,
            "The business must have remaining tokens"
        );

        // 4.Get token contract
        tokenContract = ERC20(_tokenAddress);

        // 5.transfer tokenAmount tokens to bussiness
        // ??????
        // business.transfer(tokenAmount);
        // 6.businessMan Related information processing
        businessState[business] = false;
        businessMember[business].tokenAmount = 0;
        businessMember[business].tokenFee = 0;
    }
}
