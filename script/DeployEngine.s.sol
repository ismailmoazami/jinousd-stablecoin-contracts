// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "lib/forge-std/src/Script.sol";
import {StablecoinEngine} from "src/StablecoinEngine.sol";
import {JinoUSD} from "src/JinoUSD.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployEngine is Script {
    address[] tokenAddresses;
    address[] priceFeedAddresses;



    function run() external returns(StablecoinEngine, JinoUSD, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address wBtcPriceFeed, address wEthPriceFeed,address wBtc, address wEth, uint256 deployerKey) = 
        config.activeNetworkConfig();
        
        tokenAddresses = [wBtc, wEth];
        priceFeedAddresses = [wBtcPriceFeed, wEthPriceFeed];
        // address jinoAddress = DevOpsTools.get_most_recent_deployment("JinoUSD", block.chainid);
        
        vm.startBroadcast(deployerKey);
        JinoUSD jino = new JinoUSD();
        StablecoinEngine stablecoin_engine = new StablecoinEngine(tokenAddresses, priceFeedAddresses, address(jino));
        jino.transferOwnership(address(stablecoin_engine));
        vm.stopBroadcast();

        return (stablecoin_engine, jino, config);
    }
}
