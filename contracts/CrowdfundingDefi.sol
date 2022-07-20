//SPDX-License-Identifier: MIT

// deploy to polygon network 
pragma solidity ^0.8.0; 
pragma abicoder v2;

// ERC20 interface
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Ownable contract 
import "@openzeppelin/contracts/access/Ownable.sol";
// Chainlink V3 Interface for data feed 
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// Aave V3 pool interface 
import "@aave/core-v3/contracts/interfaces/IPool.sol"; 
// Uniswap V3 contracts for swaps
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";


contract CrowdfundingDefi is Ownable {

    // Uniswap V3 Swap Router
    ISwapRouter public immutable swapRouter;
    // Aave V3 Polygon mainnet address
    Pool aaveV3Pool = Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    // Aave V3 Polygon testnest (mumbai) address - 0x1758d4e6f68166C4B2d9d0F049F33dEB399Daa1F;
    
    // WETH contract address on polygon 
    IERC20 public constant WETH = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    // DAI contract address on polygon 
    IERC20 public constant DAI = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    // USDT contract address on polygon  
    IERC20 public constant USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    // Matic Aave interest bearing USDT
    IERC20 public constant aUSDT = IERC20(0xDAE5F1590db13E3B40423B5b5c5fbf175515910b);
    
    // uniswap pool fee 
    uint24 public constant poolFee = 3000;

    // address of the owner of the crowdfund - not needed due to inheriting from Ownable
    // address public immutable owner;

    // keeping track of people who donated so can give them a gift later
    mapping(address => uint256) peopleWhoFunded; 
    // mapping for security check when redeeming rewards
    mapping(address => bool) thisPersonFunded;
    // tracking whether funders have claimed their rewards 
    mapping(address => bool) hasClaimedRewards;
    
    // generous people - those who donate >= 10 ETH 
    address[] public generousPeople;  
    // array of all funders 
    address[] public allFunders;

    // public funding variables 
    uint256 public fundingTarget;
    uint256 public fundingRoundDeadline;
    uint256 public fundingRaised;
    
    // variable to track when yield farming ends 
    uint256 endOfYieldPeriod; 
    // variable to store the reward to give back to donors
    uint256 giveBackToEachDonor;

    // eth price feed from chainlink 
    AggregatorV3Interface public ethUSDPriceFeed;
    // variable for the minimum funding amount - 10 usd
    uint256 public constant minimumAmount = 10 * 1e18;

    // different states and rounds of funding - you have a max. of 3 rounds to reach your funding target
    enum FUNDING_STATE {
        CLOSED,
        SERIES_A,
        SERIES_B,
        SERIES_C
    }

    FUNDING_STATE public fundingState;

    // funding state must be closed before starting a new round
    modifier startFunding() {
        require(fundingState == FUNDING_STATE.CLOSED);
        _;
    }

    // fundingState must be closed before yielding starts 
    modifier yielding() {
        require(fundingState == FUNDING_STATE.CLOSED);
        _;
    }
    
    // can only claim rewards once 
    modifier hasNotClaimedRewards() {
        require(!hasClaimedRewards[msg.sender], "You have already claimed your reward.");
        _;
        hasClaimedRewards[msg.sender] = true;
    }

    event fundingRoundStarted();
    event fundingRoundClosed();
    event someoneFunded(address indexed _person, uint256 _amount);
    event specialFunder(address indexed _gratefulTo); //these are people who donate more than or equal to 10 ETH
    event startedYieldFarming(uint256);

    constructor(uint256 _fundingTarget, address _priceFeedAddress, ISwapRouter _swapRouter) public {
        ethUSDPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        swapRouter = _swapRouter;
        fundingState = FUNDING_STATE.CLOSED;
        fundingTarget = _fundingTarget;
    }
    

    // Series A
    function openSeriesAFunding(uint _fundingRoundDeadline) external onlyOwner startFunding {
        fundingRoundDeadline = block.timestamp + (_fundingRoundDeadline * 1 days);
        fundingState = FUNDING_STATE.SERIES_A;

        emit fundingRoundStarted();
    }

    // Series B
    function openSeriesBFunding(uint _fundingRoundDeadline) external onlyOwner startFunding {
        fundingRoundDeadline = block.timestamp + (_fundingRoundDeadline * 1 days);
        fundingState = FUNDING_STATE.SERIES_B;

        emit fundingRoundStarted();
    }

    // Series C
    function openSeriesCFunding(uint _fundingRoundDeadline) external onlyOwner startFunding {
        fundingRoundDeadline = block.timestamp + (_fundingRoundDeadline * 1 days);
        fundingState = FUNDING_STATE.SERIES_C;

        emit fundingRoundStarted();
    }
    

    // end of funding round - if funding exceeds target, put extra funds in Aave to reward donators later
    function closeFundingRound() external onlyOwner returns (uint256) {
        require(fundingState != FUNDING_STATE.CLOSED, "Funding round is already closed.");
        require(fundingRoundDeadline <= block.timestamp, "Time still remains in this funding round.");

        fundingState = FUNDING_STATE.CLOSED;
        if (fundingRaised > fundingTarget) {
            _yieldFarm();
            endOfYieldPeriod = block.timestamp + 180 days;
        }

        return fundingRaised;
    }
    

    // fund function - using WETH - minimum donation of $10 worth 
    function fund(uint256 _amount) external {
        require(fundingRoundDeadline >= block.timestamp, "No funding round is currently open");
        require(
            getConversionRate(_amount) >= minimumAmount,  
            "Minimum funding is $10. Please increase your donation"
        );
        require(fundingState != FUNDING_STATE.CLOSED);
        
        WETH.transferFrom(msg.sender, address(this), _amount);
        fundingRaised += _amount;
        peopleWhoFunded[msg.sender] += _amount;
        
        // if donation is greater than 10 WETH
        if (_amount >= 10e18) {
            generousPeople.push(msg.sender);
            emit specialFunder(msg.sender);
        }
        
        thisPersonFunded[msg.sender] = true;
        allFunders.push(msg.sender);
    }
    

    // withdraw function - for owner of fundraiser to withdraw the WETH 
    function withdraw(uint256 _amount) external onlyOwner {
        WETH.transferFrom(address(this), msg.sender, _amount);
    }
    

    // internal function to interact with aave on the polygon network - will be called from the closeFundingRound function 
    function _yieldFarm() internal {
        // calculating the extra funds to use 
        uint256 leftOver = fundingRaised - fundingTarget;
        
        // convert the WETH to USDT using Uniswap V3 router:
        // approving uniswap v3 to spend the tokens 
        TransferHelper.safeApprove(address(WETH), address(swapRouter), leftOver);
        // transferring the left over to uniswap v3
        TransferHelper.safeTransferFrom(address(WETH), address(this), address(swapRouter), leftOver);
        // swap to usdt 
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(WETH),
                tokenOut: address(USDT),
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: leftOver,
                amountOutMinimum: 0, // change this later by using chainlink oracle 
                sqrtPriceLimitX96: 0 // swapping exact input amount
            });

        // This call to `exactInputSingle` will execute the swap.
        uint256 amountOut = swapRouter.exactInputSingle(params);

        // calculate how much usdt we have 
        uint256 swappedUSDT = USDT.balanceOf(address(this));
        
        // deposit USDT in Aave
        // approve, transferFrom, supply 
        USDT.approve(address(aaveV3Pool), swappedUSDT);
        USDT.transferFrom(address(this), address(aaveV3Pool), swappedUSDT);
        
        // supply the swapped usdt to aave v3
        aaveV3Pool.supply(address(USDT), swappedUSDT, address(this), 0);
        
        emit startedYieldFarming(block.timestamp);
    }

    // only after after 180 amount of days can the yieldFarming be ended  
    // when time has hit threshold, withdraw from lending pool
    function endYieldFarming() external onlyOwner {
        require(block.timestamp >= endOfYieldPeriod, "Yielding cannot end yet.");
    
        // claculate total balance on aave 
        uint totalBalance = aUSDT.balanceOf(address(this));
        // approving the pool to spend the balance
        aUSDT.approve(address(aaveV3Pool), totalBalance);
        // withdraw function from aave  
        aaveV3Pool.withdraw(address(USDT), totalBalance, address(this));
        
        // calculate the new balance of usdt 
        uint256 yieldedBalance = USDT.balanceOf(address(this));
        
        // swap the usdt back to weth on uniswap v3 
        // approving uniswap v3 to spend the tokens 
        TransferHelper.safeApprove(address(USDT), address(swapRouter), yieldedBalance);
        // transferring the left over to uniswap v3
        TransferHelper.safeTransferFrom(address(USDT), address(this), address(swapRouter), yieldedBalance);
        // swap back to weth 
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(USDT),
                tokenOut: address(WETH),
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: yieldedBalance,
                amountOutMinimum: 0, // change this later by using chainlink oracle 
                sqrtPriceLimitX96: 0 // swapping exact input amount
            });

        // This call to `exactInputSingle` will execute the swap.
        uint256 amountOut = swapRouter.exactInputSingle(params);
        
        // calculate the rewards each donor will get with an internal function
        _rewardsCalculation(); 
    }
    
    
    // internal function called at the end of endYieldFarming 
    function _rewardsCalculation() internal {
        uint256 wethHoldings = WETH.balanceOf(address(this));
        // divide the holdings by the number of people who donated 
        giveBackToEachDonor = wethHoldings / allFunders.length;
    }

    // function for donors to redeem their rewards - saves gas compared to distributing in a for loop 
    function claimRewards() external hasNotClaimedRewards {
        require(thisPersonFunded[msg.sender] = true, "You cannot claim any rewards.");
        WETH.transfer(msg.sender, giveBackToEachDonor); 
    }
    


    // functions to interact with chainlink oracle: 
    // converting the amount of ETH to USD
    function getConversionRate(uint256 ethAmount)
        public
        view
        returns (uint256)
    {
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUSD = (ethPrice * ethAmount) / 1e18;
        return ethAmountInUSD;
    }

    // function to get the price of the ETH
    function getPrice() public view returns (uint256) {
        (, int256 price, , , ) = ethUSDPriceFeed.latestRoundData();
        // converting to wei
        return uint256(price * 1e10);
    }
}
