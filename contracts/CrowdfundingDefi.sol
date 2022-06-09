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
//aave V3 pool contract 
import "@aave/aave-v3-core/contracts/protocol/pool/Pool.sol";
// aave pool interface 
import "@aave/aave-v3-core/contracts/interfaces/IPool.sol"; 
// Uniswap V3 contracts for swaps
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';


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

    // address of the owner of the crowdfund 
    address payable public owner;

    // keeping track of people who donated so can give them a gift later
    mapping(address => uint256) peopleWhoFunded; 
    // another mapping for extra security when redeeming rewards
    mapping(address => bool) thisPersonFunded;
    // generous people - those who donate >= 10 ETH 
    address payable[] public generousPeople;  

    // public funding variables 
    uint256 public fundingTarget;
    uint256 public fundingRoundDeadline;
    uint256 public fundingRaised;

    // eth price feed from chainlink 
    AggregatorV3Interface public ethUSDPricefeed;
    // variable for the minimum funding amount - 10 usd
    uint256 minimumAmount = 10 * 10**18;

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

    event fundingRoundStarted();
    event fundingRoundClosed();
    event someoneFunded(address indexed _person, uint256 _amount);
    event specialFunder(address indexed _gratefulTo); //these are people who donate more than or equal to 10 ETH
    event startedYieldFarming();

    constructor(uint256 _fundingTarget, address _crowdfundOwners, address _priceFeedAddress, ISwapRouter _swapRouter) public {
        owner = _crowdfundOwners;
        ethUSDPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        swapRouter = _swapRouter;
        fundingState = FUNDING_STATE.CLOSED;
        fundingTarget = _fundingTarget;
    }
    

    // Series A
    function openSeriesAFunding(uint256 _targetA, uint _fundingRoundDeadline) onlyOwner startFunding {
        fundingRoundDeadline = block.timestamp + _fundingRoundDeadline days;
        fundingState = FUNDING_STATE.SERIES_A;

        emit fundingRoundStarted();
    }

    // Series B
    function openSeriesBFunding(uint256 _targetB, uint _fundingRoundDeadline) onlyOwner startFunding {
        fundingRoundDeadline = block.timestamp + _fundingRoundDeadline days;
        fundingState = FUNDING_STATE.SERIES_B;

        emit fundingRoundStarted();
    }

    // Series C
    function openSeriesCFunding(uint256 _targetC, uint _fundingRoundDeadline) onlyOwner startFunding {
        fundingRoundDeadline = block.timestamp + _fundingRoundDeadline days;
        fundingState = FUNDING_STATE.SERIES_C;

        emit fundingRoundStarted();
    }
    

    // end of funding round - if funding exceeds target, put extra funds in Aave to reward donators later
    function closeFundingRound() onlyOwner returns (uint256) {
        require(fundingState != FUNDING_STATE.CLOSED, "Funding round is already closed.");
        require(fundingRoundDeadline <= now, "Time still remains in this funding round.");

        fundingState = FUNDING_STATE.CLOSED;
        if (fundingRaised > fundingTarget) {
            _yieldFarm();
        }

        return fundingRaised;
    }
    

    // fund function - minimum donation of $10
    function fund() external payable {
        require(fundingRoundDeadline >= block.timestamp, "No funding round is currently open");
        require(
            msg.value >= 0.0005 ether, // change this later to use getConversionRate function 
            "Minimum funding is $10. Please increase your donation"
        );
        require(fundingState != FUNDING_STATE.CLOSED);

        fundingRaised += msg.value;
        peopleWhoFunded[msg.sender] += msg.value;

        if (msg.value >= 10 ether) {
            generousPeople.push(msg.sender);
            emit specialFunder(msg.sender);
        }
        
        thisPersonFunded[msg.sender] = true;
    }
    

    // withdraw function - for owner of fundraiser
    function withdraw(uint256 _amount) payable onlyOwner {
        payable(msg.sender).transfer(_amount);
    }
    

    // internal function to interact with aave on the polygon network - will be called from the closeFundingRound function 
    function _yieldFarm(address _aaveTokenAddress) internal {
        // calculating the extra funds to use 
        uint256 leftOver = fundingRaised - fundingTarget;
        
        // convert the WETH to USDT using Uniswap V3 router  

        // deposit USDT in Aave
        // transferFrom, approve, supply 
        // time period? - 30-180days..?  

        // supply the swapped usdt to aave v3
        // aaveV3Pool.supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode);
        
        emit startedYieldFarming();
        // withdraw after x amount of days - would need to create another func => endYield   
    }


    // when time has hit threshold, withdraw from lending pool
    function endYieldFarming() private onlyOwner {
        // call withdraw function from aave ipool interface 
        // aaveV3Pool.withdraw(address asset, uint256 amount, address to);
        
    }
    

/*
    // function to reward donors - or they can claim instead to save gas
    function rewardDonators() internal payable {
    }
*/

    // function for donors to redeem their gift/rewards - saves gas
    function claimRewards() external payable {
        require(thisPersonFunded[msg.sender] = true, "You cannot claim any rewards.");
        
        // uint256 rewards;
        // calculation...
        // payable(msg.sender).transfer(rewards); 
    }


    // converting the amount of ETH to USD
    function getConversionRate(uint256 ethAmount)
        public
        view
        returns (uint256)
    {
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUSD = (ethPrice * ethAmount) / 1000000000000000000;
        return ethAmountInUSD;
    }

    // function to get the price of the ETH
    function getPrice() public view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        // converting to wei
        return uint256(answer * 10000000000);
    }
}
