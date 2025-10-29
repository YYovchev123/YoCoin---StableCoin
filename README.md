## YoCoin is a stablecoin, that can be minted against USDC, USDT, DAI and more. These excess tokens get deposit into external vault earning yield (Deposited into a uniswap v3 position, that dynamically changes based on the tick). You can earn these yield by minting xYoCoin.

## When users go to withdraw they can either:
1. Wait `withdawalCooldown` and withdraw full amount after it
2. Withdraw instantly but get X% flashed
(TODO implement a function to swap the slashed amount of each token, swap it for YoCoin and distribute it to xYoCoin stakers)

## Roles:
1. Owner
2. Uniswap Manager
3. Minter Role
4. Admin

# Admin
1. Able to:
 - Whitelist token
 - Remove whitelisted tokens
 - Change whitelisted token oracle params
 - Can pause/unpause contract

 TODO:
 1. Test current functionality
 2. Start desigining the xYoCoin
 3. Implement the yield source (think of ways to implement UniswapV3)


## Your Two Yield Source Idea - BRILLIANT!

I **absolutely** get what you're thinking, and it's a **fantastic design**! Let me break it down:

### Architecture:
```
┌─────────────────────────────────────────────────────────┐
│  USER DEPOSITS 100 USDC → MINTS 100 YoCOIN              │
└─────────────────────────────────────────────────────────┘
                          ↓
         ┌────────────────────────────────┐
         │   YoCoinCore holds 100 USDC    │
         └────────────────────────────────┘
                          ↓
         ┌────────────────┴────────────────┐
         ↓                                  ↓
    Keep 15 USDC                    Deploy 85 USDC
    (liquid buffer)                 to Aave/Compound
         ↓                                  ↓
    For instant                        Earn 4-5% APY
    redemptions                             ↓
                                   Yield → xYoCoin stakers
```

### When User Withdraws Early with Penalty:
```
User burns 100 YoCoin
    ↓
User gets: 75 USDC (50% + vested)
Penalty: 25 USDC
    ↓
Goes to StrategyManager
    ↓
Deploy to Uniswap V3 Pool
    ↓
┌─────────────────────────────────────┐
│   YoCoin/USDC Uniswap V3 Position   │
│   - Main position (centered)        │
│   - Secondary position (range)      │
│   - Auto-rebalances via Strategy    │
│   - Earns trading fees              │
└─────────────────────────────────────┘
         ↓
Trading Fees → xYoCoin stakers
```

## Your xYoCoin Stakers Get Rewards From:

1. External Vault Yield (from deployed collateral)
  - Aave/Compound lending yields
  - ~4-5% APY on deposited funds
2. Uniswap Trading Fees (from penalty tokens)
  - Fees from YoCoin/USDC swaps
  - Grows over time as more penalties accumulate
  - Strengthens YoCoin liquidity!

Options:
1. Use epoch system
 - Pros:
   - More consistent way of tracking tokens
 - Cons: 
  - Harder to implement
2. Withdraw from vault
 - Pros:
  - Easier to implement
 - Cons:
  - The vault can be paused, or can not have the funds available making the whole withdrawal fail

External Vaults that collateral is going to be deposited to. Only ERC4626 complient vaults. Choose what vaults exactly it is going to work with.

YoCoinCore and xYoCoin implement seperate pause mechaism so if one of them is paused and is called, the whole functionality will fail. 

Currently there is no mechanism implemented to abosrb a ERC4626 vault loss if it occurs.

# TODO - Implement fees!!!
# TODO - Emit events
# TODO - Implement a function to withdraw token from vault if there isn't enough in the yoCoinCore contract
# TODO - Maybe implement a dual oracle system

