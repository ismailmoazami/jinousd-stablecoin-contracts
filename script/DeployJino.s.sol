// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "lib/forge-std/src/Script.sol";
import {JinoUSD} from "src/JinoUSD.sol";

contract DeployJino is Script {

    function run() external returns(JinoUSD){
        JinoUSD jino = deployJino();
        return jino;
    }

    function deployJino() public returns(JinoUSD) {
        vm.startBroadcast();
        JinoUSD jino = new JinoUSD();
        vm.stopBroadcast();
        return jino;
    }

}