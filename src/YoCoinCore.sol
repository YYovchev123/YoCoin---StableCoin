// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {YoCoin} from "./YoCoin.sol";
import {IYoCoinCore} from "./interfaces/IYoCoinCore.sol";
import {IYoOracle} from "./interfaces/IYoOracle.sol";
import {YoCoin} from "./YoCoin.sol";
import {IYoStrategyManager} from "./interfaces/IYoStrategyManager.sol";
import {IRoleManager} from "./interfaces/IRoleManager.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IxYoCoin} from "./interfaces/IxYoCoin.sol";

// added for testing purposes
import {console} from "forge-std/console.sol";

/*
██╗   ██╗  ██████╗  ██████╗ ██████╗ ██╗███╗   ██╗
██║   ██║ ██╔═══██╗██╔════ ╗██╔══██╗██║████╗  ██║
╚ ████╔╝║ ██║   ██║██║     ║██║  ██║██║██╔██╗ ██║
╚ ████╔╝  ██║   ██║██║     ║██║  ██║██║██║╚██╗██║
 ╚████╔╝  ╚██████╔╝╚██████╔╝██████╔╝██║██║ ╚████║
  ╚═══╝    ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝
*/
contract YoCoinCore is IYoCoinCore, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @notice YoCoin address
    YoCoin yoCoin;
    /// @notice YoOracle address
    IYoOracle oracle;
    /// @notice Role Manager address
    IRoleManager roleManager;
    /// @notice Strategy Manager address
    IYoStrategyManager strategyManager;
    /// @notice The xYoCoin contract address
    IxYoCoin xYoCoin;
    
    uint256 redeemRequestId;

    uint256 totalPendingWithrawals;
    /// @notice The minimum price the collateral needs to be
    uint256 public constant MIN_PRICE = 99 * 1e16; // 0.99 * 1e18
    /// @notice The withdrawal cooldown period
    uint256 public constant WITHDRAWAL_COOLDOWN = 30 days; // 30 days

    /// @notice AddressSet of whitelisted tokens
    EnumerableSet.AddressSet whitelistedTokens;
    /// @notice AddressSet of whitelisted yield sources
    EnumerableSet.AddressSet whitelistedYieldSources;
    /// @notice User -> CollateralToken -> DepositedAmount
    mapping(address user => mapping(address token => uint256 amount)) userCollateral;
    /// @notice CollateralToken -> Info About the Token
    mapping(address collateralToken => CollateralInfo collateralTokenInfo) public collateralInfo;
    /// @notice Yield Source -> Info About the Yield Source
    mapping(address yieldSource => YieldSource yieldSourceInfo) public yieldSourceInfo;
    /// @notice User -> RedeemRequestId -> Redeem Request
    mapping(address user => mapping(uint256 redeemRequestId => RedeemRequest redeemRequest)) redeemRequests;
    
    /**
     * 
     * @param _yoCoin The yoCoin address
     * @param _oracle The address of the oracle
     * @param _roleManager The address of the role manager contract
     * @param _strategyManager The address of the strategy manager contract
     */
    constructor(address _yoCoin, address _oracle, address _roleManager, address _strategyManager, address _xYoCoin) {
        redeemRequestId = 1;
        yoCoin = YoCoin(_yoCoin);
        oracle = IYoOracle(_oracle);
        roleManager = IRoleManager(_roleManager);
        strategyManager = IYoStrategyManager(_strategyManager);
        xYoCoin = IxYoCoin(_xYoCoin);
    }

    // MODIFIERS
    /**
     * @dev Checks if msg.sender has admin role
     */
    modifier onlyAdminRole() {
        if(!roleManager.hasRole(msg.sender, IRoleManager.Role.ADMIN)) revert IRoleManager.NotAdmin();
        _;
    }

    // EXTERNAL FUNCTIONS
    /**
     * 
     * @param collateralToken The collateral token address
     * @param amount The amount that the user wants to deposit
     * @dev Mints YoCoin 1:1 with the provided amount
     * @dev Accepts only whitelisted stablecoins
     */
    function mintYoCoin(address collateralToken, uint256 amount) external whenNotPaused returns(uint256) {
        return _mintYoCoin(collateralToken, amount);
    }

    /**
     * 
     * @param collateralToken The collateral token address
     * @param amount The amount that the user wants to withdraw
     * @param receiver The address who is going to receive the tokens
     * @dev Creates a RedemRequest which can be later finalized or withdrawn early with penalty
     * @dev Burn YoCoin tokens 1:1 with redeemed amount
     */
    function startRedeemRequest(address collateralToken, uint256 amount, address receiver) external whenNotPaused returns(uint256 _redeemRequestId) {
        if(!whitelistedTokens.contains(collateralToken)) revert NotWhitelistedToken();
        if(receiver == address(0)) revert ZeroAddress();
        if(userCollateral[msg.sender][collateralToken] < amount) revert ZeroAmount();

        _redeemRequestId = redeemRequestId;
        userCollateral[msg.sender][collateralToken] -= amount;
        redeemRequests[msg.sender][redeemRequestId] = RedeemRequest({
            collateralToken: collateralToken,
            amount: amount,
            receiver: receiver,
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + WITHDRAWAL_COOLDOWN
        });
        ++redeemRequestId;

        uint256 scaledAmount = amount * 10 ** (18 - collateralInfo[collateralToken].tokenDecimals);
        totalPendingWithrawals += scaledAmount;
        yoCoin.burn(msg.sender, scaledAmount);
    }

    /**
     * @param requestId The requestId of the RedeemRequest
     * @dev If full withdraw cooldown has passed transfer all of the tokens to the user
     * @dev If the RedeemRequest is still active calculate the releasable amount (50% + released)
     * @dev Transfers excess tokens to `strategyManager` to earn rewards for xYoCoin stakers
     * @dev Deletes RedeemRequest
     */
    function redeemCollateralInstantly(uint256 requestId) external returns(uint256 totalReleased) {
        RedeemRequest memory redeemRequest = redeemRequests[msg.sender][requestId];
        if(redeemRequest.startTimestamp == 0) revert InvalidRedeemRequest();
        if(block.timestamp >= redeemRequest.endTimestamp) {
            return _finalizeRedeemRequest(requestId);
        } else {
            // TODO Check if the calculations are correct!!!
            uint256 timePassed = block.timestamp - redeemRequest.startTimestamp;
            uint256 tokenPerTimeUnit = redeemRequest.amount / WITHDRAWAL_COOLDOWN;
            uint256 initialRelease = redeemRequest.amount / 2; // Releasing 50% instantly
            uint256 released = (timePassed * tokenPerTimeUnit) / 2;
            totalReleased = initialRelease + released;
            IERC20(redeemRequest.collateralToken).safeTransfer(redeemRequest.receiver, totalReleased);
            uint256 leftOver = redeemRequest.amount - totalReleased;
            // Tranfer remaining to strategyManager to be staked in Uniswap position
            // TODO Maybe call a function to increase the uniswap position
            totalPendingWithrawals -= redeemRequest.amount * 10 ** (18 - IERC20Metadata(redeemRequest.collateralToken).decimals());
            delete redeemRequests[msg.sender][requestId];
            IERC20(redeemRequest.collateralToken).safeTransfer(address(strategyManager), leftOver);
        }
    }

    /**
     * @param requestId The requestId of the RedeemRequest
     * @dev Full withdraw cooldown has passed transfer all of the tokens to the user 
     * @dev Deletes RedeemRequest
     */
    function finalizeRedemRequest(uint256 requestId) external {
        _finalizeRedeemRequest(requestId);
    }

    // ADMIN FUNCTIONS
    /**
     * 
     * @param collateralToken Collateral token address to be whitelisted
     * @param _priceFeed The price feed address
     * @param _tokenDecimals The decimals of the collateral token
     * @param _priceFeedDecimals The decimals of the priceFeed 
     * @param _validityPeriod The period where the price is not stale
     */
    function addWhitelistedCollateralToken(address collateralToken, address _priceFeed, uint8 _tokenDecimals, uint8 _priceFeedDecimals, uint256 _validityPeriod) external onlyAdminRole {
        if(!whitelistedTokens.add(collateralToken)) revert CollateralTokenAlreadyAdded();
        collateralInfo[collateralToken] = CollateralInfo({
            priceFeed: _priceFeed,            
            tokenDecimals: _tokenDecimals,           
            priceFeedDecimals: _priceFeedDecimals,         
            validityPeriod: _validityPeriod   
        });
    }

    /**
     * @param collateralToken Collateral token address to be removed from the whitelist
     * @dev Deletes collateralInfo
     * @dev Only callable by Admin
     * audit It is accepted risk that a collateral token may be removed and then users cannot redeem.
     */
    function removeWhitelistedCollateralToken(address collateralToken) external onlyAdminRole {
        if(!whitelistedTokens.remove(collateralToken)) revert CollateralTokenNotAdded();
        delete collateralInfo[collateralToken];
    }
    
    /**
     * 
     * @param collateralToken The address of the Collateral token
     * @param _priceFeed The new price feed address
     * @param _priceFeedDecimals The new price feed's decimals
     * @param _validityPeriod The new validity period
     * @dev Only callable by Admin
     */
    function changeWhitelistedCollateralPriceFeed(address collateralToken, address _priceFeed, uint8 _priceFeedDecimals, uint256 _validityPeriod) external onlyAdminRole {
        if(!whitelistedTokens.contains(collateralToken)) revert NotWhitelistedToken();
            collateralInfo[collateralToken] = CollateralInfo({
            priceFeed: _priceFeed,            
            tokenDecimals: collateralInfo[collateralToken].tokenDecimals,           
            priceFeedDecimals: _priceFeedDecimals,         
            validityPeriod: _validityPeriod   
        });
    }

    // TODO Add documentation
    function addWhitelistedYieldSource(
        address _vault,
        address _token,
        address _vaultToken,
        uint256 _maxCap
    ) external onlyAdminRole {
        if(!whitelistedYieldSources.add(_vault)) revert YieldSourceAlreadyAdded();
        yieldSourceInfo[_vault] = YieldSource({
            token: _token,
            vault: _vault,
            vaultToken: _vaultToken,
            maxCap: _maxCap,
            depositedAmount: 0
        });
    }

    // TODO Add documentation
    function removeWhitelistedYieldSource(address _vault) external onlyAdminRole {
        // @audit Might need to change to vault.balanceOf(address(this))
        if(yieldSourceInfo[_vault].depositedAmount != 0) revert TokensStillInYieldSource();
        if(!whitelistedYieldSources.remove(_vault)) revert YieldSourceNotAdded();
        delete yieldSourceInfo[_vault];
    }

    // @audit Might need to add a check of what % of the tokens supply can be deposited
    function depositCollateralExternaly(
        address _vault,
        uint256 _amount
    ) external onlyAdminRole whenNotPaused {
        YieldSource memory _yieldSource = yieldSourceInfo[_vault];
        IERC20(_yieldSource.token).approve(address(_vault), _amount);
        IERC4626(_vault).deposit(_amount, address(this));

        uint256 totDeposited = _totalAssetsInVault(_vault);
        // revert if the amount is greater than the max cap
        if (_yieldSource.maxCap > 0 && totDeposited > _yieldSource.maxCap) {
            revert MaxCapReached();
        }
        yieldSourceInfo[_vault].depositedAmount = totDeposited;
    }

    function depositMultipleCollateralExternaly(
        address[] memory _vaults,
        uint256[] memory _amounts
    ) external onlyAdminRole whenNotPaused {
        uint256 _vaultsLen = _vaults.length;
        // check if the vaults and methods are the same length, check also if arguments have the same length
        if (_vaultsLen != _amounts.length) {
            revert InvalidLengths();
        }

        for(uint256 i = 0; i < _vaultsLen; i++) {    
            YieldSource memory _yieldSource = yieldSourceInfo[_vaults[i]];
            IERC20(_yieldSource.token).approve(address(_vaults[i]), _amounts[i]);
            IERC4626(_vaults[i]).deposit(_amounts[i], address(this));

            uint256 totDeposited = _totalAssetsInVault(_vaults[i]);
            // revert if the amount is greater than the max cap
            if (_yieldSource.maxCap > 0 && totDeposited > _yieldSource.maxCap) {
                revert MaxCapReached();
            }
            yieldSourceInfo[_vaults[i]].depositedAmount = totDeposited;
        }
    }

    function depositAccruedYield() external onlyAdminRole whenNotPaused {
        uint256 yoCoinSupply = yoCoin.totalSupply() + totReservedWithdrawals;
        uint256 totalCollaterals = _getTotalCollateralAmountScaled();
        uint256 yieldGained = totalCollaterals > yoCoinSupply ? totalCollaterals - yoCoinSupply : 0;
        if(yieldGained > 0) {
            // Mint yoCoin to this address 
            yoCoin.mintForCore(yieldGained);
            // TODO: Deposit it to xYoCoin stakers as rewards
            xYoCoin.depositRewards(yieldGained\);
        }
    }

    function rescueERC20Token(address tokenAddress, uint256 amount, address to) external onlyAdminRole {
        if(whitelistedTokens.contains(tokenAddress)) revert CannotRescueWhitelistedTokens();
        IERC20(tokenAddress).safeTransfer(to, amount);
    }

    // @audit Do we need this function if we don't have `receive` or `fallback`?
    function rescueETH(uint256 amount, address to) external onlyAdminRole {
        (bool success, ) = to.call{value: amount}();
        if(!success) revert CallNotSuccessful();
    }


    /**
     * @dev Only callable by Admin
     */
    function pause() external onlyAdminRole {
        _pause();
    }

    /**
     * @dev Only callable by Admin
     */
    function unpause() external onlyAdminRole {
        _unpause();
    }

    // INTERNAL FUNCTIONS
    function _mintYoCoin(address collateralToken, uint256 amount) internal returns(uint256 scaledAmount) {
        CollateralInfo memory _collateralInfo = collateralInfo[collateralToken];
        if(!whitelistedTokens.contains(collateralToken)) revert NotWhitelistedToken();
        if(oracle.getPrice(_collateralInfo.priceFeed, _collateralInfo.priceFeedDecimals, _collateralInfo.validityPeriod) < MIN_PRICE) revert CollateralPriceBelowThreshold();
        if(amount <= 0) revert ZeroAmount();

        userCollateral[msg.sender][collateralToken] += amount;

        scaledAmount = amount * 10 ** (18 - collateralInfo[collateralToken].tokenDecimals);
        yoCoin.mint(msg.sender, scaledAmount);

        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), amount);
        emit YoCoinMinted(msg.sender, scaledAmount);
    }

    function _finalizeRedeemRequest(uint256 requestId) internal returns(uint256 amountToSend) {
        RedeemRequest memory redeemRequest = redeemRequests[msg.sender][requestId];
        if(redeemRequest.startTimestamp == 0) revert InvalidRedeemRequest();
        if(block.timestamp < redeemRequest.endTimestamp) revert RequestNotFinalized();
        amountToSend = redeemRequest.amount;
        totalPendingWithrawals -= redeemRequest.amount * 10 ** (18 - IERC20Metadata(redeemRequest.collateralToken).decimals());
        IERC20(redeemRequest.collateralToken).safeTransfer(redeemRequest.receiver, amountToSend);
        delete redeemRequests[msg.sender][requestId];   
    }
    
    /**
     * @notice Get the total value in this contract of an ERC4626 vault.
     * @param vault  The address of the ERC4626 vault token.
     * @return The total value of the ERC4626 vault in this contract.
     */
    function _totalAssetsInVault(address vault) internal view returns (uint256) {
        return IERC4626(vault).previewRedeem(IERC4626(vault).balanceOf(address(this)));
    }

    function _totalAssetsInVaultScaled(address vault) internal view returns (uint256) {
        return IERC4626(vault).previewRedeem(IERC4626(vault).balanceOf(address(this))) * 10 ** (18 - IERC20Metadata(vault.asset()).decimals());
    }


    // TODO Might need to make this function public 
    function _getTotalCollateralAmountScaled() internal returns(uint256 totCollaterals) {
        IERC20Metadata _collateral;
        address[] memory allCollaterals = whitelistedTokens.values();
        uint256 collateralsLen = allCollaterals.length;
        for(uint256 i = 0; i < collateralsLen; i++) {
            _collateral = IERC20Metadata(allCollaterals[i]);
            totCollaterals += _collateral.balanceOf(address(this)) * (10 ** (18 - _collateral.decimals()));
        }

        uint256 sourcesLen = whitelistedYieldSources.length();
        for(uint256 i = 0; i < sourcesLen; i++) {
            totCollaterals += _totalAssetsInVaultScaled(whitelistedYieldSources.at(i));
        }
    }
}