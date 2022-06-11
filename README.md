#### Elements of this:
- You have 3 funding rounds to reach your target funding; Series A, Series B, Series C 
- If by the end of the all your funding rounds you have raised more than your target, the extra funds will be swapped for USDT on Uniswap V3 and supplied to Aave V3 to generate yield on the extra funds 
- These supplied funds will be kept on Aave V3 for 180 days 
- After 180 days has passed, the owners of the crowdfund can call endYieldFarming that ends the yielding, which will withdraw the USDT from Aave, then swap it back to WETH on Uniswap
- Once the owners have ended the yielding & the funds have been swapped, those who donated to the crowdfund can redeem their gift by calling a claimRewards function 
