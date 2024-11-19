// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

contract SVPN_Subscription is Ownable {
    IUniswapV2Factory private immutable i_uniswapV2Factory;
    IUniswapV2Router02 private immutable i_uniswapV2Router02;
    AggregatorV3Interface private immutable i_priceFeed;
    using PriceConverter for uint256;
    using SafeERC20 for IERC20;
    struct UserInfo {
        address user;
        string paymentId;
        string packageType;
    }

    uint256 public nextID;
    uint256 public constant IDLength = 15;
    uint256 public paymentAmountMonthlyInUsd;
    uint256 public paymentAmountYearlyInWeth;
    uint256 public s_totalYearlySales;
    uint256 public s_totalMonthlySales;
    uint256 public s_totalOverallSales;
    address private immutable i_weth;

    event IDGenerated(
        address indexed payer,
        string generatedID,
        string paymentType
    );
    event MonthlyPaymentAmountUpdated(uint256 newPaymentAmount);
    event YearlyPaymentAmountUpdated(uint256 newPaymentAmount);
    event TokensRecieved(address indexed tokenAddress_, uint256 amount_);

    mapping(address => string[]) private _userIDs;
    mapping(address => UserInfo[]) private s_userToUserInfo;
    mapping(address => uint256) private s_tokenToAmount;

    constructor(
        address _uniswapV2Factory,
        address _weth,
        address _uniswapV2Router02,
        address _priceFeed,
        uint256 _initialPaymentMonthlyAmount,
        uint256 _initialPaymentYearlyAmount,
        uint256 _totalYearlySales,
        uint256 _totalMonthlySales,
        uint256 _totalOverallSales
    ) Ownable(msg.sender) {
        i_uniswapV2Factory = IUniswapV2Factory(_uniswapV2Factory);
        i_uniswapV2Router02 = IUniswapV2Router02(_uniswapV2Router02);
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_weth = _weth;
        paymentAmountMonthlyInUsd = _initialPaymentMonthlyAmount;
        paymentAmountYearlyInWeth = _initialPaymentYearlyAmount;
        nextID = 1;
        s_totalYearlySales = _totalYearlySales;
        s_totalMonthlySales = _totalMonthlySales;
        s_totalOverallSales = _totalOverallSales;
    }

    // Approve Uniswap V2 router first with the token.
    function payForUniqueIDMonthly(address _tokenAddress) external {
        require(_tokenAddress != address(0), "token doesn't exist");
        require(IERC20(_tokenAddress).totalSupply() > 0, "Not a valid token");
        require(
            IERC20Metadata(_tokenAddress).decimals() == 18,
            "Decimals mismatch"
        );
        require(
            IERC20(_tokenAddress).balanceOf(msg.sender) > 0,
            "Not enough Balance"
        );
        uint256 usdPerGivenToken = _getTokenPriceInUsd(_tokenAddress);
        uint256 requiredTokens = (paymentAmountMonthlyInUsd * 1e18) /
            usdPerGivenToken;

        require(IERC20(_tokenAddress).balanceOf(msg.sender) >= requiredTokens);
        bool success = IERC20(_tokenAddress).transferFrom(
            msg.sender,
            owner(),
            requiredTokens
        );
        require(success, "Transfer Failed");
        s_tokenToAmount[_tokenAddress] += requiredTokens;
        string memory generatedID = generateUniqueID();
        _userIDs[msg.sender].push(generatedID);
        s_userToUserInfo[msg.sender].push(
            UserInfo({
                user: msg.sender,
                paymentId: generatedID,
                packageType: "Monthly"
            })
        );
        s_totalMonthlySales += 1;
        emit IDGenerated(msg.sender, generatedID, "Monthly");
        emit TokensRecieved(_tokenAddress, requiredTokens);
    }

    // Approve Uniswap V2 router first with the token.
    function payForUniqueIDYearly(address _tokenAddress) external {
        require(_tokenAddress != address(0), "token doesn't exist");
        require(IERC20(_tokenAddress).totalSupply() > 0, "Not a valid token");
        require(
            IERC20Metadata(_tokenAddress).decimals() == 18,
            "Decimals mismatch"
        );
        require(
            IERC20(_tokenAddress).balanceOf(msg.sender) > 0,
            "Not enough Balance"
        );
        uint256 usdPerGivenToken = _getTokenPriceInUsd(_tokenAddress);
        uint256 requiredTokens = (paymentAmountYearlyInWeth * 1e18) /
            usdPerGivenToken;

        require(IERC20(_tokenAddress).balanceOf(msg.sender) >= requiredTokens);
        bool success = IERC20(_tokenAddress).transferFrom(
            msg.sender,
            owner(),
            requiredTokens
        );
        require(success, "Transfer Failed");
        s_tokenToAmount[_tokenAddress] += requiredTokens;
        string memory generatedID = generateUniqueID();
        _userIDs[msg.sender].push(generatedID);
        s_userToUserInfo[msg.sender].push(
            UserInfo({
                user: msg.sender,
                paymentId: generatedID,
                packageType: "Yearly"
            })
        );
        s_totalYearlySales += 1;
        emit IDGenerated(msg.sender, generatedID, "Yearly");
    }

    function generateUniqueID() internal returns (string memory) {
        bytes memory characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        bytes memory result = new bytes(IDLength);
        bool unique;
        uint256 attempts = 0;

        do {
            bytes32 hash = keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    msg.sender,
                    nextID,
                    attempts
                )
            );
            unique = true;

            for (uint256 i = 0; i < IDLength; i++) {
                uint256 randIndex = uint256(uint8(hash[i % 32])) %
                    characters.length;
                result[i] = characters[randIndex];
            }

            string memory newID = string(result);
            for (uint256 i = 0; i < _userIDs[msg.sender].length; i++) {
                if (
                    keccak256(abi.encodePacked(_userIDs[msg.sender][i])) ==
                    keccak256(abi.encodePacked(newID))
                ) {
                    unique = false;
                    break;
                }
            }

            attempts++;
        } while (!unique && attempts < 10); // Prevent infinite loops

        require(
            unique,
            "Failed to generate a unique ID after several attempts."
        );
        nextID++;
        return string(result);
    }

    function withdrawETH() external onlyOwner {
        require(address(this).balance > 0, "Not enough Balance");
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "withdraw failed");
    }

    // use ethers.parseEther(""); in the front-end
    function updateMonthlyPaymentAmount(
        uint256 _newPaymentAmount
    ) external onlyOwner {
        require(_newPaymentAmount > 0, "Invalid payment amount");
        paymentAmountMonthlyInUsd = _newPaymentAmount;
        emit MonthlyPaymentAmountUpdated(_newPaymentAmount);
    }

    // use ethers.parseEther(""); in the front-end
    function updateYearlyPaymentAmount(
        uint256 _newPaymentAmount
    ) external onlyOwner {
        require(_newPaymentAmount > 0, "Invalid payment amount");
        paymentAmountYearlyInWeth = _newPaymentAmount;
        emit YearlyPaymentAmountUpdated(_newPaymentAmount);
    }

    function getUserIDs(address user) external view returns (string[] memory) {
        return _userIDs[user];
    }

    function _getTokenPriceInUsd(
        address _tokenAddress
    ) internal view returns (uint256 priceInUsd) {
        address pair = i_uniswapV2Factory.getPair(_tokenAddress, i_weth);
        require(pair != address(0), "Not a valid pair on Uniswap");
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        (uint112 reserve0, uint112 reserve1, ) = pairContract.getReserves();
        uint256 tokenReserve = uint256(reserve0);
        uint256 wethReserve = uint256(reserve1);
        uint256 priceInWeth = (wethReserve *
            (10 ** IERC20Metadata(_tokenAddress).decimals())) / tokenReserve;
        uint256 priceWithFeeAdjustment = ((priceInWeth * 997) / 1000) / 2;
        priceInUsd = PriceConverter.getConversionRate(
            priceWithFeeAdjustment,
            i_priceFeed
        );
    }

    function getUserInfo(
        address _user
    ) public view returns (UserInfo[] memory) {
        return s_userToUserInfo[_user];
    }

    function getTotalYearlySales() public view returns (uint256) {
        return s_totalYearlySales;
    }

    function getTotalMonthlySales() public view returns (uint256) {
        return s_totalMonthlySales;
    }

    function getOverallSales() public view returns (uint256) {
        return s_totalMonthlySales + s_totalYearlySales;
    }

    function getMonthlySubscriptionPrice() public view returns (uint256) {
        return paymentAmountMonthlyInUsd;
    }

    function getYearlySubscriptionPrice() public view returns (uint256) {
        return paymentAmountYearlyInWeth;
    }
}
