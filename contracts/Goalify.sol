pragma solidity ^0.5.4;

contract Goalify {
    /* Players - sponsor, staker, and judge
       Action - 1) staker will bet on himself to accomplish a goal in a specific duration of time, 
                2) sponsor will also bet an amount of ether on staker as extra incentive, assuming sponsor is interested in see staker succeed
                3) a smart contract will lock their ethers and dictate terms of payout at end of the time duration, terms will include (goal statement, betsize, time duration)
                4) at end of the period, the judge will look at the goals achieved and approve outcome. The approval and outcome will determine payout.
                5) result can come out either two ways: 1) staker achieves the goal and wins his original stake fund + amount staked from sponsor or 2) staker fail to achieve his/her goal, loses his stake, sponsor gets full refund upon failure
                6) BUT staker has a chance to get his money back by placing another bet on himself to win his money back (Still under Developement)
                7) Staker is allowed two tries to get his/her money back, if still failure afte two tries, the entire lost amount will donate to Golify Dapp. The money will then be used to help other stakers to achieve their goals (Still under Developement).
    
       Step 1) Create Goal
       Step 2) Bet on Goal - sponsor and stakers will bet, 
       Step 3) Approve Outcome - judge will approve outcome as succcess or failure
       Step 4) Distribute - judge approves or disapproves, sponsor and staker re-create the Bet
 
       Variables - 3 players / addresses; time - start, end, eduration; money - pot, betsize, dappFees; goal statement; tries; State enum; Outcome enum */
    
    enum State {CREATED, BETTING, APPROVED, CLOSED}
    enum Outcome {SUCCEESS, FAILURE}

    uint dappFee;
    address public admin;
    
    struct Goal {
        uint id;
        string goalStatement;
        uint betSize;
        uint pot;
        uint start;
        uint duration;
        uint end;
        address payable staker;
        address payable sponsor;
        address payable judge;
        State state;
        Outcome outcome;
        uint tries;
    }
    
    mapping(uint => Goal) public goals;
    uint public goalId; // number of attempts / tries on goal
    
    constructor() public {
        // require(fee > 0 && fee < 100, "fee is a percentage that should be between 1% to 99%");
        dappFee = 5; // Dapp will take 5% of stake and sponsor's bet. staker will pay sponsor fee. 
        admin = msg.sender;
    }
    
    function createGoal(string calldata _statement, uint _betSize, uint _duration, address payable _sponsor, address payable _judge) external payable {
        require(_duration > 86400, "Goal must be at least 1 day long"); // 86400 second = 24 hours / one day
        Goal storage goal = goals[goalId];
        goal.id = goalId;
        goal.goalStatement = _statement;
        goal.betSize = _betSize;
        goal.duration = _duration;
        goal.start = now;
        goal.end = now + _duration;

        goal.staker = msg.sender;
        goal.sponsor = _sponsor;
        goal.judge = _judge;
        
        goal.state = State.CREATED;
        goalId++;
    }
    
    function bet(uint _goalId) external payable capBet(_goalId) refundExcess(_goalId) {
        Goal storage goal = goals[_goalId];
        // require((now - goal.start) < 86400, 
        require(msg.sender == goal.staker || msg.sender == goal.sponsor, "only staker and sponsor can deposit");
        require(msg.value >= goal.betSize, "staker and sponsor must bet amount greater or equal to betSize");
        require(goal.state == State.CREATED || goal.state == State.BETTING, "state must be in CREATED or BETTING");
        
        if(now > (goal.start + 86400)) {msg.sender.transfer(msg.value); delete goals[_goalId];} // "must bet within 24 hours of goal creation, otherwise goal will self delete");
        
        goal.pot += goal.betSize;
        goal.state = State.BETTING;
    }
    
    function approve(uint _goalId, uint decision) external returns(bool){
        Goal storage goal = goals[_goalId];
        require(msg.sender == goal.judge, "only judge can approve");
        require(decision == 1 || decision == 2, 'decision is either 1 for SUCCEESS or 2 for FAILURE');
        require(goal.state == State.BETTING, "state must be in BETTING");
        
        if(decision == 1) {goal.outcome = Outcome.SUCCEESS; goal.state = State.APPROVED;}
        if(decision == 2) {goal.outcome = Outcome.FAILURE; goal.state = State.APPROVED;}
        
        distribute(_goalId);
        
        return true;
    }
    
    function distribute(uint _goalId) internal {
        Goal storage goal = goals[_goalId];
        require(goal.outcome == Outcome.SUCCEESS || goal.outcome == Outcome.FAILURE, "judge must have given approval for SUCCEESS or FAILURE");
        require(goal.state == State.APPROVED, "state must be in APPROVED");
        if(goal.outcome == Outcome.SUCCEESS) { // SUCCEESS
            goal.staker.transfer(goal.pot * (100 - dappFee) / 100); //staker wins his deposit + sponsor money;
            goal.pot = 0;
        }
        if(goal.outcome == Outcome.FAILURE) { //FAILURE
            goal.sponsor.transfer(goal.betSize); //sponsor get his money back, staker loses his stake
            goal.pot -= goal.betSize;
        }
        
        goal.state = State.CLOSED;
    }
    
    modifier refundExcess(uint _goalId) {
        _;
        uint _betSize = goals[_goalId].betSize;
        uint refund = msg.value - _betSize;
        msg.sender.transfer(refund);
    }
    
    modifier capBet(uint _goalId) {
        require(goals[_goalId].pot < (2 * goals[_goalId].betSize), "cannot bet more than 2 times, as pot size is capped at double betSize");
        _;
    }
}
    