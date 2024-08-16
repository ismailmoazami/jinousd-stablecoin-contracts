// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StablecoinEngine} from "../../src/StablecoinEngine.sol";
import {JinoUSD} from "../../src/JinoUSD.sol";
import {DeployEngine} from "script/DeployEngine.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";


contract EngineTest is Test {

    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 tokenAmount);
    event CollateralWithdrawn(address indexed fromWithdrawn, address indexed toWithdrawn, address indexed collateralAddress, uint256 amountToWithdraw);


    DeployEngine deployer; 
    JinoUSD jino;
    StablecoinEngine engine;
    HelperConfig config;
    address wBtc;
    address wBtcPriceFeed;
    address wEthPriceFedd;

    address[] public priceFeedAddresses;
    address[] public tokenAddresses;

    address USER = makeAddr('user');

    uint256 constant private STARTING_BALANCE = 150e18;
    uint256 constant private PRECISION = 1e18;

    function setUp() external {
        vm.prank(USER);
        deployer = new DeployEngine();
        (engine, jino, config) = deployer.run();
        (wBtcPriceFeed, , wBtc, , ) = config.activeNetworkConfig();
        ERC20Mock(wBtc).mint(USER, STARTING_BALANCE);
    }

    function testGetUsdValue() external view{
        uint amount = 12e18;
        uint256 expectedValue = amount * 55000;

        uint usdValue = engine.getUsdValue(wBtc, amount);
        console.log("usdValue: ", usdValue);
        console.log("expectedValue: ", expectedValue);
        assert(usdValue == expectedValue);

    }

    // Deposit tests

    modifier depositCollateral() { 
        vm.startPrank(USER);
        uint amount = 15e18;

        ERC20Mock(wBtc).approve(address(engine), amount);
        engine.depositCollateral(wBtc, amount);
        vm.stopPrank();
        _;
    }

    function testDepositCollateral() external {
        vm.startPrank(USER);
        uint amount = 15e18;

        ERC20Mock(wBtc).approve(address(engine), amount);
        engine.depositCollateral(wBtc, amount);
        vm.stopPrank();        
        uint256 userDeposited = engine.getUserDepositedCollateralByToken(USER, wBtc);

        assert(userDeposited == amount);

    }

    function testRevertIfDepositZero() external {
        vm.startPrank(USER);
        ERC20Mock(wBtc).approve(address(engine), 0);
        
        vm.expectRevert(StablecoinEngine.StablecoinEngine__MoreThanZero.selector);
        engine.depositCollateral(wBtc, 0);
        vm.stopPrank();

    }

    function testCanNotDepositWithNotAllowedCollateral() external {
        vm.startPrank(USER); 
        uint256 amount = 100e18;
        ERC20Mock newToken = new ERC20Mock('NewToken', 'NT', USER, amount); 
        newToken.approve(address(engine), amount); 

        vm.expectRevert(StablecoinEngine.StablecoinEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(newToken), amount);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetUserInfo() external depositCollateral {
        (uint256 totalJinoMintedByUser, uint256 totalCollateralValue) = engine.getUserInfo(USER);

        uint256 expectedJinoMinted = 0;
        uint256 expectedCollateralValue = 15e18 * 55000;

        assert(totalJinoMintedByUser == expectedJinoMinted);
        assert(totalCollateralValue == expectedCollateralValue);
    }

    function testCanEmitCollateralDepositedEvent() external {
        vm.startPrank(USER);
        ERC20Mock(wBtc).approve(address(engine), 15e18);
        vm.expectEmit(true, true, false, true);
        
        emit CollateralDeposited(USER, wBtc, 15e18);
        engine.depositCollateral(wBtc, 15e18);
        vm.stopPrank();
    } 

    // Withdraw tests
    function testCanWithdrawCorrectly() external {
        uint256 amount = 15e18;
        uint256 amountToWithdraw = 3e18;
        uint256 amountOfJinoToMint = 300000e18;

        vm.startPrank(USER);
        ERC20Mock(wBtc).approve(address(engine), amount);
        engine.depositCollateral(wBtc, amount);
        engine.mintJinoUSD(amountOfJinoToMint);
        jino.approve(address(engine), amountOfJinoToMint);

        engine.withdrawCollateral(wBtc, amountToWithdraw);

        vm.stopPrank();
        uint256 expected = amount - amountToWithdraw;
        uint256 collateralLeft = engine.getUserDepositedCollateralByToken(USER, wBtc);
        assert(collateralLeft == expected);
    }

    function testCanEmitCollateralWithdrawnEvent() external depositCollateral {
        uint256 amountToWithdraw = 3e18;
        uint256 amountOfJinoToMint = 300000e18;
        vm.startPrank(USER);

        engine.mintJinoUSD(amountOfJinoToMint);
        jino.approve(address(engine), amountOfJinoToMint);

        vm.expectEmit(true, true, true, true);
        emit CollateralWithdrawn(USER, USER, wBtc, amountToWithdraw);

        engine.withdrawCollateral(wBtc, amountToWithdraw);
    }

    // Mint tests 
    function testCanMintJino() external {
        
    }

    // Constructor tests
    function testRevertIfTokenAddressesAndPriceFeedAddressesLengthsDontMatch() external {
        priceFeedAddresses = [wBtcPriceFeed, wEthPriceFedd];
        tokenAddresses = [wBtc];

        vm.expectRevert(StablecoinEngine.StablecoinEngine__TokenAddressesAndPriceFeedsLengthMustBeTheSame.selector);
        new StablecoinEngine(priceFeedAddresses, tokenAddresses, address(jino));
    }

    function testGetTokenAmountFromUsd() external view { 
        uint256 usdAmount = 220 ether;
        uint256 expectedAmount = 0.004 ether;
        console.log("expectedAmount: ", expectedAmount);
        uint256 actualAmount = engine.getTokenAmountFromUsd(wBtc, usdAmount);
        console.log("actualAmount: ", actualAmount);
        assert(actualAmount == expectedAmount);
    }

}