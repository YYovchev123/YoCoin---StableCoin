// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {YoCoin} from "../src/YoCoin.sol";
import {YoCoinCore} from "../src/YoCoinCore.sol";
import {RoleManager} from "../src/RoleManager.sol";
import {IRoleManager} from "../src/interfaces/IRoleManager.sol";
import {ERC20Mock} from "./mock/ERC20Mock.sol";
import {PriceOracleMock} from "./mock/PriceOracleMock.sol";

contract YoCoinCoreTest is Test {
    YoCoin yoCoin;
    YoCoinCore yoCoinCore;
    RoleManager roleManager;

    ERC20Mock USDC;
    ERC20Mock DAI;
    PriceOracleMock oracleMock;

    address owner = makeAddr("owner");
    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address strategyManager = makeAddr("strategyManager");
    address priceFeed = makeAddr("priceFeed");

    function setUp() public {
        vm.warp(block.timestamp);
        USDC = new ERC20Mock(6);
        DAI = new ERC20Mock(18);
        oracleMock = new PriceOracleMock();
        roleManager = new RoleManager(owner);
        yoCoin = new YoCoin(address(roleManager));
        yoCoinCore = new YoCoinCore(address(yoCoin), address(oracleMock), address(roleManager), strategyManager);

        vm.startPrank(owner);
        roleManager.grantRole(admin, IRoleManager.Role.ADMIN);
        roleManager.grantRole(address(yoCoinCore), IRoleManager.Role.MINTER);
        roleManager.grantRole(address(yoCoinCore), IRoleManager.Role.BURNER);
        vm.stopPrank();

        vm.startPrank(admin);
        yoCoinCore.addWhitelistedCollateralToken(address(USDC), address(priceFeed), 6, 8, 2 hours);
        yoCoinCore.addWhitelistedCollateralToken(address(DAI), address(priceFeed), 18, 8, 2 hours);
        vm.stopPrank();
    }

    function testDAIMintYoCoin() public {
        uint256 amount1 = 100e18;
        vm.startPrank(user1);
        DAI.mint(user1, amount1);
        DAI.approve(address(yoCoinCore), amount1);
        yoCoinCore.mintYoCoin(address(DAI), amount1);
        vm.stopPrank();

        console.log("User 1 YoCoin Balance: ", yoCoin.balanceOf(user1));
    }

    function testUSDCMintYoCoin() public {
        uint256 amount1 = 100e6;
        vm.startPrank(user1);
        USDC.mint(user1, amount1);
        USDC.approve(address(yoCoinCore), amount1);
        yoCoinCore.mintYoCoin(address(USDC), amount1);
        vm.stopPrank();

        console.log("User 1 YoCoin Balance: ", yoCoin.balanceOf(user1));
    }

    function testWithdrawWaitingForFullPeriod() public {
        uint256 amount1 = 100e6;
        vm.startPrank(user1);
        USDC.mint(user1, amount1);
        USDC.approve(address(yoCoinCore), amount1);
        yoCoinCore.mintYoCoin(address(USDC), amount1);
        vm.stopPrank();

        console.log("User 1 YoCoin Balance: ", yoCoin.balanceOf(user1));

        vm.startPrank(user1);
        uint256 user1RedeemId = yoCoinCore.startRedeemRequest(address(USDC), amount1, user1);
        console.log("user1RedeemId: ", user1RedeemId);
        console.log("User 1 YoCoin Balance After withdrawal request: ", yoCoin.balanceOf(user1));
        console.log("User 1 USDC Balance After withdrawal request: ", USDC.balanceOf(user1));
        vm.warp(block.timestamp + 30 days);
        yoCoinCore.finalizeRedemRequest(1);
        console.log("User 1 USDC Balance After withdrawal request: ", USDC.balanceOf(user1)); // 100.000000
        vm.stopPrank();
        
    }

    function testWithdrawRevertsIfFullWithdrawInWaitingPeriod() public {
        uint256 amount1 = 100e6;
        vm.startPrank(user1);
        USDC.mint(user1, amount1);
        USDC.approve(address(yoCoinCore), amount1);
        yoCoinCore.mintYoCoin(address(USDC), amount1);
        vm.stopPrank();

        console.log("User 1 YoCoin Balance: ", yoCoin.balanceOf(user1));

        vm.startPrank(user1);
        uint256 user1RedeemId = yoCoinCore.startRedeemRequest(address(USDC), amount1, user1);
        console.log("user1RedeemId: ", user1RedeemId);
        console.log("User 1 YoCoin Balance After withdrawal request: ", yoCoin.balanceOf(user1));
        console.log("User 1 USDC Balance After withdrawal request: ", USDC.balanceOf(user1));
        vm.warp(block.timestamp + 10 days);
        vm.expectRevert();
        yoCoinCore.finalizeRedemRequest(1);
        vm.stopPrank();
    }

    function testWithdrawHalfWayThroughThePeriod() public {
                uint256 amount1 = 100e6;
        vm.startPrank(user1);
        USDC.mint(user1, amount1);
        USDC.approve(address(yoCoinCore), amount1);
        yoCoinCore.mintYoCoin(address(USDC), amount1);
        vm.stopPrank();

        console.log("User 1 YoCoin Balance: ", yoCoin.balanceOf(user1));

        vm.startPrank(user1);
        uint256 user1RedeemId = yoCoinCore.startRedeemRequest(address(USDC), amount1, user1);
        console.log("user1RedeemId: ", user1RedeemId);
        console.log("User 1 YoCoin Balance After withdrawal request: ", yoCoin.balanceOf(user1));
        console.log("User 1 USDC Balance After withdrawal request: ", USDC.balanceOf(user1));
        vm.warp(block.timestamp + 15 days);
        yoCoinCore.redeemCollateralInstantly(1);
        console.log("User 1 USDC Balance After withdrawal request: ", USDC.balanceOf(user1));
        vm.stopPrank();
    }
}