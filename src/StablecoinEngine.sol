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
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

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
    event CollateralWithdrawn(address indexed fromWithdrawn, address indexed toWithdrawn, address indexed collateralAddress, uint256 amountToWithdraw);
    
    //////////////////
    // Errors      //
    ////////////////
    
    error StablecoinEngine__MoreThanZero();
    error StablecoinEngine__NotAllowedToken();
    error StablecoinEngine__TokenAddressesAndPriceFeedsLengthMustBeTheSame();
    error StablecoinEngine__TransferFailed();
    error StablecoinEngine__HealthFactorTooLow(uint256 userHealthFactor);
    error StablecoinEngine__MintFailed();
    error StablecoinEngine__HealthFactorIsOk();
    error StablecoinEngine__HealthFactorNotImproved();
    error StablecoinEngine__AddressNotZero();

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
            if(_tokenAddresses[i] == address(0)) {
                revert StablecoinEngine__AddressNotZero();
            }
            
            if(_priceFeeds[i] == address(0)) {
                revert StablecoinEngine__AddressNotZero();
            }

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
    public MustBeMoreThanZero(_amount) isAllowedToken(_collateralTokenAddress)
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
     * @param _collateralTokenAddress contract address of the token that user deposits (can be WETH or WBTC)
     * @param _amountOfCollateral Amount of collateral tokens that user deposits
     * @param _amountToMint Amount of JinoUSD tokens that user wants to mint
     * @notice Users must have more collateral than amount of JinoUSD they want to mint
    */
    function depositCollateralAndMintJino(address _collateralTokenAddress, uint256 _amountOfCollateral, uint256 _amountToMint) external {
        depositCollateral(_collateralTokenAddress, _amountOfCollateral);
        mintJinoUSD(_amountToMint);
    }

    function withdrawCollateral(address _collateralAddress, uint256 _amountToWithdraw) 
    public 
    MustBeMoreThanZero(_amountToWithdraw)
    nonReentrant
    {
        _withdrawCollateral(_collateralAddress, _amountToWithdraw, msg.sender, msg.sender);

        _revertIfHealthFactorBroken(msg.sender);
    }

    function withdrawCollateralForJino(address _collateralAddress, uint256 _amountOfCollateralToWithdraw, uint256 amountOfJinoToBurn) 
    public
    {
        burnJino(amountOfJinoToBurn);        
        withdrawCollateral(_collateralAddress, _amountOfCollateralToWithdraw);
    }

    /* 
     * @dev Mint JinoUSD tokens
     * @param _amount Amount of JinoUSD tokens that user wants to mint
     * @notice Users must have more collateral than amount of JinoUSD they want to mint
    */
    function mintJinoUSD(uint256 _amount) public MustBeMoreThanZero(_amount) nonReentrant{
        s_jinoUsdMinted[msg.sender] += _amount;
        _revertIfHealthFactorBroken(msg.sender);
        bool success = i_jinoUSD.mint(msg.sender, _amount);
        if(!success){
            revert StablecoinEngine__MintFailed();
        }
    }

    function burnJino(uint256 _amount) MustBeMoreThanZero(_amount) public nonReentrant{
        
        _burnJino(_amount, msg.sender, msg.sender);
        
    }

    /* 
    * @param _collateralAddress contract address of the token that user deposits (can be WETH or WBTC)
    * @param _user Address of the user that is being liquidated
    * @param _amountOfDebt Amount of JinoUSD tokens that user owes
    * @notice Liquidator gets a bonus for liquidating a user
    * @notice Liquidator must have a health factor of more than 1
    */
    function liquidate(address _collateralAddress, address _user, uint256 _amountOfDebt) external 
    MustBeMoreThanZero(_amountOfDebt)
    nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(_user);
        if(startingUserHealthFactor > MIN_HEALTH_FACTOR) {
            revert StablecoinEngine__HealthFactorIsOk();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(_collateralAddress, _amountOfDebt);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / THRESHOLD_PRECISION;

        uint256 totalTokensToWithdraw = tokenAmountFromDebtCovered + bonusCollateral;
        uint256 userTotalCollateral = s_depositedCollateral[_user][_collateralAddress];

        if(totalTokensToWithdraw > userTotalCollateral) {
            totalTokensToWithdraw = userTotalCollateral;
        }
        

        _withdrawCollateral(_collateralAddress, totalTokensToWithdraw, _user, msg.sender);
        _burnJino(_amountOfDebt, _user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(_user);
        if(endingUserHealthFactor <= startingUserHealthFactor){
            revert StablecoinEngine__HealthFactorNotImproved();
        }

        _revertIfHealthFactorBroken(msg.sender);

    }

    function addAllowedToken(address _tokenAddress) external onlyOwner{
        if(_tokenAddress == address(0)) {
            revert StablecoinEngine__AddressNotZero();
        }
        s_allowedTokens[_tokenAddress] = true;
    }


    //////////////////////////////
    //    Internal Functions   //
    ////////////////////////////

    function _withdrawCollateral(address _collateralAddress, uint256 _amountToWithdraw, address _from, address _to) internal {
        s_depositedCollateral[_from][_collateralAddress] -= _amountToWithdraw;
        emit CollateralWithdrawn(_from, _to, _collateralAddress, _amountToWithdraw);
        bool success = IERC20(_collateralAddress).transfer(_to, _amountToWithdraw);
        if(!success){
            revert StablecoinEngine__TransferFailed();
        }
    }

    function _burnJino(uint256 _amount, address _onBehalfOf, address _fromJinoOf) internal {
        s_jinoUsdMinted[_onBehalfOf] -= _amount;
        bool success = i_jinoUSD.transferFrom(_fromJinoOf, address(this), _amount);
        if(!success){
            revert StablecoinEngine__TransferFailed();
        }
        i_jinoUSD.burn(_amount);
    }
    
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
        if(totalJinoMintedByUser == 0) {
            return type(uint256).max;
        }
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

    function getUserDepositedCollateralByToken(address _user, address _token) public view returns(uint256) {
        return s_depositedCollateral[_user][_token];
    }

    function getUserJinoMinted(address _user) public view returns(uint256) {
        return s_jinoUsdMinted[_user];
    }

    function getTokenAmountFromUsd(address _token, uint256 _usdAmount) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokensPriceFeed[_token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (_usdAmount * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getUserInfo(address _user) external view returns(uint256, uint256) {
        (uint256 totalJinoMintedByUser, uint256 totalCollateralValueOfUser) = _getUserInfo(_user);
        return (totalJinoMintedByUser, totalCollateralValueOfUser);
    } 

    function healthFactor(address _user) external view returns(uint256) {
        return _healthFactor(_user);
    }

}