// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IxYoCoin} from "./interfaces/IxYoCoin.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IYoCoinCore} from "./interfaces/IYoCoinCore.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/*
██╗   ██╗  ██████╗  ██████╗ ██████╗ ██╗███╗   ██╗
██║   ██║ ██╔═══██╗██╔════ ╗██╔══██╗██║████╗  ██║
╚ ████╔╝║ ██║   ██║██║     ║██║  ██║██║██╔██╗ ██║
╚ ████╔╝  ██║   ██║██║     ║██║  ██║██║██║╚██╗██║
 ╚████╔╝  ╚██████╔╝╚██████╔╝██████╔╝██║██║ ╚████║
  ╚═══╝    ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝
*/
// TODO: Check if the inheritance is correct!
contract XYoCoin is ERC4626, Pausable IxYoCoin {
    using SafeERC20 for IERC20;

    /// @notice Token symbol.
    string public constant SYMBOL = "xYo";
    /// @notice Token name.
    string public constant NAME = "xYoCoin";
    /// @notice reference value for 100% fee
    uint256 public constant FEE_100 = 100_000; // 100% fee
    /// @notice max fee
    uint256 public constant MAX_FEE = 20_000; // max fee is 20%

    /// @notice Rewards vesting period in seconds.
    uint256 public rewardsVesting;
    /// @notice Amount of rewards to release.
    uint256 public rewards;
    /// @notice Timestamp when rewards were last deposited.
    uint256 public rewardsLastDeposit;
    /// @notice fee on interest earned
    uint256 public fee;
    /// @notice address to receive fees
    address public feeReceiver;
    /// @notice YoCoinCore contract address.
    IYoCoinCore public yoCoinCore;
    /// @notice Role Manager address
    IRoleManager roleManager;

    modifier onlyAdminRole() {
        if(!roleManager.hasRole(msg.sender, IRoleManager.Role.ADMIN)) revert IRoleManager.NotAdmin();
        _;
    }


    constructor(address _yoCoin, address _yoCoinCore, address _roleManager, address _feeReceiver) ERC4626(_yoCoin) ERC20(NAME, SYMBOL) {
        yoCoinCore = IYoCoinCore(_yoCoinCore);
        roleManager = IRoleManager(_roleManager);

        // set initial values
        rewardsVesting = 7 days;
        fee = FEE_100 / 20; // 5%
        feeReceiver = _feeReceiver;
    }

    //////////////////////////
    /// Internal functions ///
    //////////////////////////

    /// @dev See {ERC4626Upgradeable-_deposit}.
    /// @dev if paused, deposits are not allowed
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override whenNotPaused {
        super._deposit(caller, receiver, assets, shares);
    }

    /// @dev See {ERC4626Upgradeable-_withdraw}.
    /// @dev if paused, withdraws are not allowed
    function _withdraw(address caller, address receiver, address _owner, uint256 assets, uint256 shares) internal override whenNotPaused {
        super._withdraw(caller, receiver, _owner, assets, shares);
    }

    /// @notice Get the amount of unvested rewards.
    /// @return _unvested The amount of unvested rewards.
    function _getUnvestedRewards() internal view returns (uint256 _unvested) {
        uint256 _rewardsVesting = rewardsVesting;
        uint256 _rewards = rewards;
        uint256 _timeSinceLastDeposit = block.timestamp - rewardsLastDeposit;
        // calculate unvested rewards
        if (_timeSinceLastDeposit < _rewardsVesting) {
            _unvested = _rewards - (_rewards * _timeSinceLastDeposit / _rewardsVesting);
        }
    }

    //////////////////////
    /// View functions ///
    /////////////////////

    /// @dev See {ERC4626Upgradeable-decimals}.
    function decimals() public view virtual override(ERC4626, ERC20) returns (uint8) {
        return 18;
    }

    /// @dev See {IERC4626-totalAssets}. Interest is vested over a period of time and is not immediately claimable.
    function totalAssets() public view override returns (uint256) {
        // return total assets minus unvested rewards
        uint256 _totAssets = super.totalAssets();
        uint256 _unvested = _getUnvestedRewards();
        if (_unvested > _totAssets) {
        return 0;
        }
        return _totAssets - _unvested;
    }

    ///////////////////////
    /// Admin functions ///
    ///////////////////////

    /// @notice Update the rewards vesting period.
    /// @param _rewardsVesting The new rewards vesting period.
    function updateRewardsVesting(uint256 _rewardsVesting) external onlyAdminRole {
        uint256 _lastDeposit = rewardsLastDeposit;
        // check that old rewards are all vested and that the new vesting period won't re-vest rewards already released
        if (block.timestamp < _lastDeposit + rewardsVesting || block.timestamp < _lastDeposit + _rewardsVesting) {
            revert NotAllowed();
        }
        rewardsVesting = _rewardsVesting;
    }

    /// @notice Update the fee parameters.
    /// @param _fee The new fee.
    /// @param _feeReceiver The new fee receiver.
    function updateFeeParams(uint256 _fee, address _feeReceiver) external onlyAdminRole {
        if (_fee > MAX_FEE) {
        revert FeeTooHigh();
        }
        fee = _fee;
        feeReceiver = _feeReceiver;
    }

    /// @notice Deposit rewards (ParetoDollars) to the contract.
    /// @dev Any unvested rewards will be added to the new rewards.
    /// @param amount The amount of rewards to deposit.
    function depositRewards(uint256 amount) external {
        // check that caller is queue contract
        // TODO Add -> `|| msg.sender != yoStrategyManager)
        if (msg.sender != yoCoinCore) {
            revert NotAllowed();
        }
    I   ERC20 _asset = IERC20(asset());
        // transfer rewards from caller to this contract
        _asset.safeTransferFrom(msg.sender, address(this), amount);

        uint256 _fee = fee;
        uint256 _feeAmount;
        if (_fee > 0) {
            // transfer fees to fee receiver
            // if funds are donated to the contract with direct transfer, fees won't be accounted on the donated amount
            _feeAmount = amount * _fee / FEE_100;
            asset.safeTransfer(feeReceiver, _feeAmount);
        }

        // update rewards data, add unvested rewards if any
        rewards = amount - _feeAmount + _getUnvestedRewards();
        rewardsLastDeposit = block.timestamp;

        emit RewardsDeposited(amount - _feeAmount);
    }

    /// @dev See {IERC4626-maxDeposit}. Returns 0 if paused.
    function maxDeposit(address _who) public view override returns (uint256) {
        return paused() ? 0 : super.maxDeposit(_who);
    }

    /// @dev See {IERC4626-maxMint}. Returns 0 if paused.
    function maxMint(address _who) public view override returns (uint256) {
        return paused() ? 0 : super.maxMint(_who);
    }

    /// @dev See {IERC4626-maxWithdraw}. Returns 0 if paused.
    function maxWithdraw(address _who) public view override returns (uint256) {
        return paused() ? 0 : super.maxWithdraw(_who);
    }

    /// @dev See {IERC4626-maxRedeem}. Returns 0 if paused.
    function maxRedeem(address _who) public view override returns (uint256) {
        return paused() ? 0 : balanceOf(_who);
    }
}