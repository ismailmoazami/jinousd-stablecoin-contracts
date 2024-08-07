// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {JinoUSD} from "src/JinoUSD.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/* 
 * @title StablecoinEngine
 * @author Ismail Moazami
 * @notice Smart contract for Managing and controlling the Jino stablecoin system
 * @dev StablecoinEngine uses wBTC and wETH for colloteral and pegged to 1 USD
 * Jino stablecoin should be always overcolloratized 
*/
contract StablecoinEngine is Ownable, ReentrancyGuard {
    
    ////////////////////////
    // State Variables   //
    //////////////////////

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant THRESHOLD_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => bool) private s_allowedTokens;
    mapping(address token => address priceFeed) private s_tokensPriceFeed;
    mapping(address user => mapping(address token => uint256 collateralAmount)) private s_depositedCollateral;
    mapping(address user => uint256 jinoUsdMintedAmount) private s_jinoUsdMinted;

    address[] private s_allowedTokensList;
    JinoUSD private immutable i_jinoUSD;

    //////////////////
    // Events      //
    ////////////////    

    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 tokenAmount);

    //////////////////
    // Errors      //
    ////////////////
    
    error StablecoinEngine__MoreThanZero();
    error StablecoinEngine__NotAllowedToken();
    error StablecoinEngine__TokenAddressesAndPriceFeedsLengthMustBeTheSame();
    error StablecoinEngine__TransferFailed();
    error StablecoinEngine__HealthFactorTooLow(uint256 userHealthFactor);
    error StablecoinEngine__MintFailed();

    /////////////////
    // Modifiers   //
    /////////////////
    
    modifier MustBeMoreThanZero(uint256 _amount) {
        if(_amount <= 0) {
            revert StablecoinEngine__MoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if(!s_allowedTokens[_token]) {
            revert StablecoinEngine__NotAllowedToken();
        }
        _;
    }

    /////////////////
    // Functions   //
    /////////////////
    
    constructor(address[] memory _tokenAddresses, address[] memory _priceFeeds, address _jinoUSD) Ownable(msg.sender){
        if(_tokenAddresses.length != _priceFeeds.length) {
            revert StablecoinEngine__TokenAddressesAndPriceFeedsLengthMustBeTheSame();
        }

        for(uint256 i=0; i < _tokenAddresses.length; i++) {
            s_tokensPriceFeed[_tokenAddresses[i]] = _priceFeeds[i];
            s_allowedTokens[_tokenAddresses[i]] = true;
            s_allowedTokensList.push(_tokenAddresses[i]);
        }

        i_jinoUSD = JinoUSD(_jinoUSD);
    }

    ///////////////////////////
    // External Functions   //
    /////////////////////////

    /* 
    * @param _collateralTokenAddress contract address of the token that user deposits (can be WETH or WBTC)
    * @param _amount Amount of collateral tokens that user deposits
    */
    function depositCollateral(address _collateralTokenAddress, uint256 _amount) 
    external MustBeMoreThanZero(_amount) isAllowedToken(_collateralTokenAddress)
    nonReentrant()
    {
        require(IERC20(_collateralTokenAddress).balanceOf(msg.sender) >= _amount, "Not enough balance");
        s_depositedCollateral[msg.sender][_collateralTokenAddress] += _amount;
        emit CollateralDeposited(msg.sender, _collateralTokenAddress, _amount);

        bool success = IERC20(_collateralTokenAddress).transferFrom(msg.sender, address(this), _amount);
        if(!success){
            revert StablecoinEngine__TransferFailed();
        }
    }

    /* 
     * @dev Mint JinoUSD tokens
     * @param _amount Amount of JinoUSD tokens that user wants to mint
     * @notice Users must have more collateral than amount of JinoUSD they want to mint
    */
    function mintJinoUSD(uint256 _amount) external MustBeMoreThanZero(_amount) nonReentrant{
        s_jinoUsdMinted[msg.sender] += _amount;
        _revertIfHealthFactorBroken(msg.sender);
        bool success = i_jinoUSD.mint(msg.sender, _amount);
        if(!success){
            revert StablecoinEngine__MintFailed();
        }
    }

    function addAllowedToken(address _tokenAddress) external onlyOwner{
        require(_tokenAddress != address(0));
        s_allowedTokens[_tokenAddress] = true;
    }


    //////////////////////////////
    //    Internal Functions   //
    ////////////////////////////

    function _getUserInfo(address _user) internal view returns(uint256, uint256) {
        uint256 totalJinoMintedByUser = s_jinoUsdMinted[_user];
        uint256 totalCollateralValueOfUser = getAccountCollateralValue(_user);
        return (totalJinoMintedByUser, totalCollateralValueOfUser);
    }

    /*
     * @dev Return how close is a user to liquidations
     * If a user goes below 1, then they will be liquidated
    */
    function _healthFactor(address _user) private view returns(uint256) {
        (uint256 totalJinoMintedByUser, uint256 totalCollateralValueOfUser) = _getUserInfo(_user);
        uint256 collateralAdjustedValue = (totalCollateralValueOfUser * LIQUIDATION_THRESHOLD) / THRESHOLD_PRECISION;
        return (collateralAdjustedValue * PRECISION) / totalJinoMintedByUser;
    }

    function _revertIfHealthFactorBroken(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);

        if(userHealthFactor < MIN_HEALTH_FACTOR) {
            revert StablecoinEngine__HealthFactorTooLow(userHealthFactor);
        }
    }

    //////////////////////////////
    // public view Functions   //
    ////////////////////////////

    function getAccountCollateralValue(address _user) public view returns(uint256) {
        uint totalValueInUSD = 0;
        for(uint256 i = 0; i < s_allowedTokensList.length; i++) {
            address collateralAddress = s_allowedTokensList[i];
            uint256 amount = s_depositedCollateral[_user][collateralAddress];
            totalValueInUSD += getUsdValue(collateralAddress, amount);
        }
        return totalValueInUSD;
    }

    function getUsdValue(address _token, uint256 _amount) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokensPriceFeed[_token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) / PRECISION;
    }

}