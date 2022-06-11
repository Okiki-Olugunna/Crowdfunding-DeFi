#### Elements of this:
- You have 3 funding rounds to reach your target; Series A, Series B, Series C 
- At the end of the all your funding rounds, if you raised more than your target, the extra funds will be swapped for USDT on Uniswap V3 and supplied to Aave V3 to generate yield on the extra funds 
- These funds will are kept on Aave for 180 days
- After 180 days has passed, the owners of the crowdfund can call that ends the yielding, which will withdraw the USDT from Aave, then swap it back to WETH on Uniswap
- Once this is complete, those who donated to the crowdfund can redeem their gift by calling a claimRewards function 
