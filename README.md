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