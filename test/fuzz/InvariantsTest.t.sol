// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {StablecoinEngine} from "src/StablecoinEngine.sol";
import {JinoUSD} from "src/JinoUSD.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployEngine} from "script/DeployEngine.s.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {

    StablecoinEngine engine; 
    JinoUSD jinoUSD; 
    HelperConfig config;
    DeployEngine deployer;
    address wbtc;
    address weth;
    Handler handler;


    function setUp() external {

        deployer = new DeployEngine();
        (engine, jinoUSD, config) = deployer.run();
        (, , wbtc, weth, ) = config.activeNetworkConfig();
        handler = new Handler(engine, jinoUSD);

        targetContract(address(handler));
        
    }


    function invariant_totalSupplyMustBeLessThanTotalCollateral() public view {
        
        uint256 totalSupply = jinoUSD.totalSupply();
        uint256 totalWBtcDeposited = IERC20(wbtc).balanceOf(address(engine));
        uint256 totalWEthDeposited = IERC20(weth).balanceOf(address(engine));

        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWBtcDeposited);
        uint256 wethValue = engine.getUsdValue(weth, totalWEthDeposited);

        console.log("wbtcValue + wethValue: ", wbtcValue + wethValue);
        console.log("totalSupply: ", totalSupply);
        console.log("timeMintCalled: ", handler.timeMintCalled());
        
        assert(wbtcValue + wethValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public view {
        engine.getUsdValue(wbtc, 1e18);
        engine.getAllowedTokens(); 
        engine.getAccountCollateralValue(msg.sender);
        engine.getUserInfo(msg.sender);
    }


}