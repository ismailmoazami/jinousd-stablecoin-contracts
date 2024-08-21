// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StablecoinEngine} from "src/StablecoinEngine.sol";
import {JinoUSD} from "src/JinoUSD.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract Handler is Test {

    StablecoinEngine engine;
    JinoUSD jinoUSD;
    ERC20Mock wbtc;
    ERC20Mock weth;
    uint256 public timeMintCalled;

    uint256 MAX_DEPOSIT_AMOUNT = type(uint96).max;  
    address USER = makeAddr("USER");
    address[] public usersWithCollateralDeposited;
    MockV3Aggregator wbtcPriceFeed;

    constructor(StablecoinEngine _engine, JinoUSD _jinoUSD) {
        engine = _engine;
        jinoUSD = _jinoUSD;
        address[] memory allowedTokens = engine.getAllowedTokens();
        wbtc = ERC20Mock(allowedTokens[0]);
        weth = ERC20Mock(allowedTokens[1]);
        wbtcPriceFeed = MockV3Aggregator(engine.getPriceFeed(address(wbtc)));
    }

    function depositCollateral(uint256 _collateralSeed, uint256 _amount) public {
        ERC20Mock collateral = _getCollateralFromSeed(_collateralSeed);
        _amount = bound(_amount, 1, MAX_DEPOSIT_AMOUNT);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, _amount);
        collateral.approve(address(engine), _amount);
        engine.depositCollateral(address(collateral), _amount);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function withdrawCollateral(uint256 _collateralSeed, uint256 _amount) public {
        ERC20Mock collateral = _getCollateralFromSeed(_collateralSeed); 
        uint256 userMaxWithdrawAmount = engine.getUserDepositedCollateralByToken(msg.sender, address(collateral));
        _amount = bound(_amount, 0, userMaxWithdrawAmount);
        

        if(_amount == 0) {
            return;
        } 
        try engine.withdrawCollateral(address(collateral), _amount) {
            // Nothing to do here
        } catch (bytes memory lowLevelData) {
            if (keccak256(abi.encodeWithSignature("StablecoinEngine__InsufficientCollateral()")) == keccak256(lowLevelData)) {
                // Caught the specific error we're interested in
                return;
            }
        }
        
    }

    function mintJino(uint256 _amount, uint256 _seed) public {
        // depositCollateral(_seed, _amount);
        if(usersWithCollateralDeposited.length == 0) {
            return;
        }
        address user = usersWithCollateralDeposited[_seed % usersWithCollateralDeposited.length];
        vm.startPrank(user);

        (uint256 totalJinoMintedByUser, uint256 totalCollateralValue) = engine.getUserInfo(user);
        
        int256 maxJinoToMint = (int256(totalCollateralValue) / 2) - int256(totalJinoMintedByUser);
        console.log("maxJinoToMint: ", maxJinoToMint);
        console.log("totalJinoMintedByUser: ", totalJinoMintedByUser);
        console.log("totalCollateralValue: ", totalCollateralValue);
        if(maxJinoToMint <= 0) {
            return;
        }
        
        _amount = bound(_amount, 0, uint256(maxJinoToMint));
        
        if(_amount == 0) {
            return;
        }

        engine.mintJinoUSD(_amount);
        timeMintCalled++;
        vm.stopPrank();
        
    }

    // This breaks the invariant!!!
    // function updateWbtcPrice(uint96 _price) public {
    //     int256 price = int256(uint256(_price));
    //     wbtcPriceFeed.updateAnswer(price);
    // }

    function _getCollateralFromSeed(uint256 _seed) internal view returns (ERC20Mock) {
        if (_seed % 2 == 0) {
            return wbtc;
        } 
        return weth;
    }

}