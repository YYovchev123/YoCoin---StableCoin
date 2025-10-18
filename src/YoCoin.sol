// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";

contract YoCoin is ERC20 {

    IRoleManager roleManager;

    constructor(address _roleManager)
        ERC20("MyToken", "MTK")
    {
        roleManager = IRoleManager(_roleManager);
    }

    function mint(address to, uint256 amount) public {
        if(!roleManager.hasRole(msg.sender, IRoleManager.Role.MINTER)) revert IRoleManager.NotMinter();
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        if(!roleManager.hasRole(msg.sender, IRoleManager.Role.BURNER)) revert IRoleManager.NotBurner();
        _burn(from, amount);
    }
}