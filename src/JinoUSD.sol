// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title Jino
 * @author Ismail Moazami
 * Collateral: BTC and ETH 
 * Minting: Algorithmic
 * Relative Stability: Pegged to US Dollar
 * @dev This is contract for stablecoin token, the main login implemented in JinoEngine
 Contract.
*/
contract JinoUSD is ERC20Burnable, Ownable{

    error Jino__MustBeMoreThanZero();
    error Jino__BurnAmountExceedsAccountBalance();
    error Jino__AddressNotZero();

    constructor() ERC20("JinoUSD", "JUSD") Ownable(msg.sender){
        
    }

    function burn(uint256 _amount) public override onlyOwner{
        if(_amount <= 0) {
            revert Jino__MustBeMoreThanZero();
        }
        if(_amount < balanceOf(msg.sender)) {
            revert Jino__BurnAmountExceedsAccountBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns(bool){
        if(_to == address(0)) {
            revert Jino__AddressNotZero();
        } 
        if(_amount <= 0) {
            revert Jino__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

}