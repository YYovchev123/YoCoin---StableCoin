// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";

/*
██╗   ██╗  ██████╗  ██████╗ ██████╗ ██╗███╗   ██╗
██║   ██║ ██╔═══██╗██╔════ ╗██╔══██╗██║████╗  ██║
╚ ████╔╝║ ██║   ██║██║     ║██║  ██║██║██╔██╗ ██║
╚ ████╔╝  ██║   ██║██║     ║██║  ██║██║██║╚██╗██║
 ╚████╔╝  ╚██████╔╝╚██████╔╝██████╔╝██║██║ ╚████║
  ╚═══╝    ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝
*/
contract YoCoin is ERC20 {

    IRoleManager roleManager;
    IYoCoinCore yoCoinCore;

    constructor(address _roleManager, address _yoCoinCore)
        ERC20("MyToken", "MTK")
    {
        roleManager = IRoleManager(_roleManager);
        yoCoinCore = IYoCoinCore(_yoCoinCore);
    }

    function mint(address to, uint256 amount) public {
        if(!roleManager.hasRole(msg.sender, IRoleManager.Role.MINTER)) revert IRoleManager.NotMinter();
        _mint(to, amount);
    }

    function mintForCore(uint256 amount) public {
        if(msg.sender != address(yoCoinCore)) revert IRoleManager.OnlyYoCoinCore();
        _mint(address(yoCoinCore), amount);
    }

    function burn(address from, uint256 amount) public {
        if(!roleManager.hasRole(msg.sender, IRoleManager.Role.BURNER)) revert IRoleManager.NotBurner();
        _burn(from, amount);
    }
}