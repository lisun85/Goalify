pragma solidity ^0.5.4;

contract Goalify {
    // Players - sponsor and staker and judge
    // Action - 1) staker will bet on himself to accomplish a goal in a specific period of time, 
    //          2) sponsor will also donate an amount of money as extra incentive for the staker, 
    //          3) a smart contract will lock their ethers and dictate terms of payout at end of the time period, terms will include (current weight, weight loss goals, start date, end date etc.)
    //          4) at end of the period, the judge will look at the goals achieved and determine payouts.
    //          5) result can come out either two ways: 1) staker achieves the goal and gets refund his amount + amount from sponsor or 2) staker doesn't achieve the goal, loses his pot, sponsor gets full refund
    //          6) BUT staker has a chance to get his money back by placing the same bet on himself, but stakes are reduced by 10% (staker bets 100 dollars on himself to lose 10 lbs, loses the bet, now can win 90 dollars back if he succeed the 2nd time)
    //          7) Allowed two chances to get your money back, if still lost then money will donate to Golify Dapp. The money will then be used to help other stakers to achieve their goals.
    
    // Step 1) Create the bet with terms
    // Step 2) Bet - sponsor and stakers will deposit, judge will be desiganted as approver
    // Step 3) Distribute - judge approves or disapproves, sponsor and staker re-create the Bet
 
    // Variables - 3 players / addresses, time - start, end, money - pot / betsize, dappFees, 
    // Enum for state - INACTIVE and ACTIVE
    
    enum State {IDLE, CREATED, BETTING, CLOSED}
    enum Outcome {SUCCEESS, FAILURE}
    
    address payable public staker;
    address payable public sponsor;
    address payable public judge;
    State public currenState = State.IDLE;
    uint betSize;
    uint betCount; // how to limit betCount to only 2 tries max?
    uint end;
    uint duration;
    uint pot;
    uint dappFees;
    address public admin;
    
    struct Goal {
        uint id;
        uint betSize;
        uint duration;
        string goalStatement;
        address payable staker;
        address payable sponsor;
        address payable judge;
        State state;
        Outcome outcome;
    }
    
    mapping(uint => Goal) public goals;
    uint public goalId; // number of attempts / tries on goal
    
    constructor(uint fee) public {
        require(fee >= .01 ether);
        fee = dappFees;
        admin = msg.sender;
    }
    
    function createGoal(string calldata _statement, uint _betSize, uint _duration) external {
        Goal storage goal = goals[goalId];
        goal.goalStatement = _statement;
        goal.betSize = _betSize;
        goal.duration = _duration;
        end = now + _duration;
        currenState = State.CREATED;
        
        goal.staker = msg.sender;
        //must set up address of sponsor and judge;
    }
    
    function bet(uint _goalId) external payable {
        Goal storage goal = goals[goalId];
        if(now > end) {msg.sender.transfer(msg.value); return;}
        require(msg.sender == staker || msg.sender == sponsor, "only staker and sponsor can deposit");
        require(msg.value == goals[goalId].betSize);
        pot += msg.value;
        goal.state = State.BETTING;
        currenState = State.BETTING;
    }
    
    function approve(uint _goalId, uint decision) external returns(bool){
        Goal storage goal = goals[goalId];
        require(msg.sender == goals[goalId].judge);
        require(decision == 1 || decision == 2, 'decision is either 1 for SUCCEESS or 2 for FAILURE');
        
        if(decision == 1) {goal.outcome = Outcome.SUCCEESS;}
        if(decision == 2) {goal.outcome = Outcome.FAILURE;}
        return true;
    }
    
    function distribute(uint _goalId) internal {
        require(approve(_goalId, decision) == true), "judge must have given approval for SUCCEESS or FAILURE");
        Goal storage goal = goals[goalId];
        if(goal.outcome == 0) { // SUCCEESS
            staker.transfer(pot); //staker wins his deposit + sponsor money;
            pot = 0;
        }
        if(goal.outcome == 1) { //FAILURE
            sponsor.transfer(goal[goalId].betSize);
            pot -= goal[goalId].betSize;
        }
        
        goal.state = State.CLOSED;
        currenState = State.CLOSED;
    }
    
}
    