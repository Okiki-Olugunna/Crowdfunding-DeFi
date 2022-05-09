//SPDX-License-Identifier: MIT

// considering deploying to polygon network 
pragma solidity ^0.8.0; 

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
//import "@aave/aave-v3-core/contracts/protocol/pool/Pool.sol";
import "@aave/aave-v3-core/contracts/interfaces/IPool.sol"; // aave pool interface 

contract CrowdfundingDefi is Ownable {

    // variable for the owner(s) if it's not just an individual doing the funding
    // this address could link to their multisig wallet if they want to 
    address payable public owner;

    // keeping track of people who donated - can give them a gift/airdop later
    mapping(address => uint256) peopleWhoFunded;
    address payable[] public generousPeople; //this array is for the airdrop/gift

    // 10usd minimum amount
    uint256 minimumAmount = 10 * 10**18;

    // variable for the funding target 
    uint256 fundingTarget;

    // 
    uint fundingRoundDeadline;

    //variable to keep track of the total funding that has been raised 
    uint256 public fundingRaised;

    // eth price feed from chainlink 
    AggregatorV3Interface public ethUSDPricefeed;

    // different states and rounds of funding
    // you have a maximum of 3 rounds to reach your funding target
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

    // if funding exceeds target, could put extra funds in a defi farm to reward donators later
    modifier yielding() {
        require(fundingState == FUNDING_STATE.CLOSED);
        _;
    }

    event fundingRoundStarted();
    event fundingRoundClosed();
    event someoneFunded(address indexed _person, uint256 _amount);
    event specialFunder(address indexed _gratefulTo); //these are people who donate more than or equal to 10 ETH
    event startedYieldFarming();

    constructor(address _priceFeedAddress, uint256 _fundingTarget, address _owners) public {
        //owner = msg.sender;
        owner = _owners;
        ethUSDPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        fundingState = FUNDING_STATE.CLOSED;
        fundingTarget = _fundingTarget;
    }

    function openSeriesAFunding(uint256 _targetA, uint _fundingRoundDeadline) onlyOwner startFunding {
        fundingRoundDeadline = _fundingRoundDeadline days;
        fundingState = FUNDING_STATE.SERIES_A;

        emit fundingRoundStarted();
    }

    function openSeriesBFunding(uint256 _targetB, uint _fundingRoundDeadline) onlyOwner startFunding {
        fundingRoundDeadline = _fundingRoundDeadline days;
        fundingState = FUNDING_STATE.SERIES_B;

        emit fundingRoundStarted();
    }

    function openSeriesCFunding(uint256 _targetC, uint _fundingRoundDeadline) onlyOwner startFunding {
        fundingRoundDeadline = _fundingRoundDeadline days;
        fundingState = FUNDING_STATE.SERIES_C;


        emit fundingRoundStarted();
    }

    // end of funding round - put extra funds in defi farm
    function closeFundingRound() onlyOwner returns (uint256) {
        require(fundingState != FUNDING_STATE.CLOSED, "Funding round is already closed.");

        if (fundingRoundDeadline <= now) {

        }

        if (fundingRaised > fundingTarget) {
            yieldFarm();
        }

        return fundingRaised;
    }

    // fund function - for anyone - amount - minimum: $10
    function fund(uint256 _amount) external payable {
        require(
            _amount >= 0.0005 ether, // change this later to use convert function 
            "Minimum funding is $10. Please increase your donation"
        );
        require(fundingState != FUNDING_STATE.CLOSED);

        fundingRaised += msg.value;
        peopleWhoFunded[msg.sender] += msg.value;
        generousPeople.push(msg.sender);

        if (msg.value >= 10 ether) {
            emit specialFunder(msg.sender);
        }
    }

    // withdraw function - for owner of fundraiser (& approved owners if done in a group - multisig wallet maybe?)
    function withdraw(uint256 _amount) onlyOwner {
        msg.sender.transfer(_amount);
    }

    // integrate with a defi protocol on the polygon/eth network
    function yieldFarm(address _aaveTokenAddress) internal {
        // deposit extra funds in a lending protocol - compound, aave, curve, instadapp, yearnfinance
        // when deciding; look into yield & fees;
        // could even convert the eth to a stablecoin to make sure donors get an assurance of a min. amount back
        // time period? - maybe 30-180days..?

        // swap eth for usdt 
        // bridge the usdt to polygon network 

        //instantiating aave interface 
        IPool aavePool;
        aavePool = IPool(_aaveTokenAddress);
        // supply the usdt to aave-v3-core 
        aavePool.supply();

        emit startedYieldFarming();
        // withdraw after x amount of days - would need to create another func => endYield
        
    }

/*
    // this way will simply deposit the eth to aave - without swapping to usdt  or bridging
    // if I decide to use this, will need to import the IWETHGateway contract and IERC20 for aWETH
    
    function yieldFarm() internal {
        // Depositing ETH through the AAVE WETH gateway
        gateway.depositETH{value: (address(this).balance) - fundingTarget}(address(this), 0); 
        
        emit startedYieldFarming();
    }
*/


    //when time has hit threshold, withdraw from lending pool
    function endYieldFarming() private onlyOwner {
        // call withdraw function from aave ipool interface 
        
    }
    
    
/*
    // Alternative way to end the farming if not bridging or swapping
    function endYieldFarming() private onlyOwner {
        aWETH.approve(address(gateway), <amount>);

        // withdrawing the interest & ETH to this contract
        gateway.withdrawETH(type(uint256).max, address(this));

        emit endedYieldFarming();
    }
*/
    

    // function to reward donors - or they can claim instead to save gas
    function rewardDonators() internal payable {
        // look into how defi protocols reward users for inspiration
    }

    // function for donors to redeem their gift/rewards
    function claimRewards() external {}


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
