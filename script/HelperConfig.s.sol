// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "lib/forge-std/src/Script.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {

    struct NetworkConfig {
        address wBtcPriceFeed;
        address wEthPriceFeed;
        address wBtc;
        address wEth;
        uint256 deployerKey;
    }

    uint8 constant DECIMALS = 8;
    uint256 constant INITIAL_ETH_PRICE = 2000e8;
    uint256 constant INITIAL_BTC_PRICE = 55000e8;
    uint256 constant INITIAL_ACCOUNT_BALANCE = 5200e18;

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;


    NetworkConfig public activeNetworkConfig;

    constructor() {
        if(block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wBtcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wEthPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wBtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            wEth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilConfig() public returns(NetworkConfig memory) {
        if(activeNetworkConfig.wBtc != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, int256(INITIAL_ETH_PRICE));
        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, int256(INITIAL_BTC_PRICE));

        ERC20Mock mockWeth = new ERC20Mock("WETH", "WETH", msg.sender, INITIAL_ACCOUNT_BALANCE);
        ERC20Mock mockWbtc = new ERC20Mock("WBTC", "WBTC", msg.sender, INITIAL_ACCOUNT_BALANCE);

        vm.stopBroadcast();

        return NetworkConfig({
            wBtcPriceFeed: address(btcUsdPriceFeed),
            wEthPriceFeed: address(ethUsdPriceFeed),
            wBtc: address(mockWbtc),
            wEth: address(mockWeth),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
