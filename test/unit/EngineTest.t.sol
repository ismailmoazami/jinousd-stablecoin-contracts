// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StablecoinEngine} from "../../src/StablecoinEngine.sol";
import {JinoUSD} from "../../src/JinoUSD.sol";
import {DeployEngine} from "script/DeployEngine.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";


contract EngineTest is Test {

    DeployEngine deployer; 
    JinoUSD jino;
    StablecoinEngine engine;
    HelperConfig config;
    address wBtc;
    address wBtcPriceFeed;

    address USER = makeAddr('user');

    uint256 constant private STARTING_BALANCE = 150e18;

    function setUp() external {
        vm.prank(USER);
        deployer = new DeployEngine();
        (engine, jino, config) = deployer.run();
        (wBtcPriceFeed, , wBtc, , ) = config.activeNetworkConfig();
        ERC20Mock(wBtc).mint(USER, STARTING_BALANCE);
    }

    function testGetUsdValue() external view{
        uint amount = 10e18;
        uint256 expectedValue = 550000e18;

        uint usdValue = engine.getUsdValue(wBtc, amount);
        
        assert(usdValue == expectedValue);

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

    function testCanWithdrawCorrectly() external {
        uint256 amount = 15e18;
        uint256 amountToWithdraw = 3e18;
        uint256 amountOfJinoToMint = 400000e18;

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
}