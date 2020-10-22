const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { assertion } = require('@openzeppelin/test-helpers/src/expectRevert');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const Goalify = artifacts.require('Goalify.sol');

contract('Goalify', (accounts) => {
let contract;
const [staker, sponsor, judge] = [accounts[1], accounts[2], accounts[3]];
const [suc, fail] = [1, 2];

before(async () => {
    contract = await Goalify.new();
    const originalStakerBalance = web3.utils.toBN(await web3.eth.getBalance(staker));
    const originalSponsorBalance = web3.utils.toBN(await web3.eth.getBalance(sponsor));
});

it('should NOT create goal if duration of the goal is less than one day', async() => {
    await expectRevert(
        contract.createGoal("goal1", 100, 86399, sponsor, judge, {from: staker}),
        "Goal must be at least 1 day long"
    );
});

it('should have created goal', async() => {
    await contract.createGoal("goal1", 100, 86401, sponsor, judge, {from: staker})

    const goal = await contract.goals(0);
    assert(goal.id.toNumber() === 0);
    assert(goal.goalStatement.toString() == "goal1");
    assert(goal.state.toNumber() === 0);
    assert(goal.judge.toString() === judge);
    assert(goal.staker.toString() === staker);
});

it('should NOT allow bet to occur if caller is not staker or sponsor', async () => {
    await expectRevert(
        contract.bet(0, {from: judge, value: 100}),
        "only staker and sponsor can deposit"
    );
});

it('should NOT allow bet to be less than betSize', async () => {
    await expectRevert(
        contract.bet(0, {from: staker, value: 99}),
        "staker and sponsor must bet amount greater or equal to betSize"
    );
})

it('made a bet', async () => {
    await contract.bet(0, {from: staker, value: 100});

    const goal = await contract.goals(0);
    assert(goal.pot.toNumber() === 100);
    assert(goal.state.toNumber() === 1);
})

// it('refunded excess', async () => {

//     const balanceSponsorBefore = web3.utils.toBN(await web3.eth.getBalance(sponsor));
    
//     const tx = await contract.bet(0, {from: sponsor, value: 1000, gasPrice: 1});
    
//     const goal = await contract.goals(0);

//     const balanceSponsorAfter = web3.utils.toBN(await web3.eth.getBalance(sponsor));

//     assert(balanceSponsorBefore.sub(balanceSponsorAfter).add(web3.utils.toBN(tx.receipt.gasUsed)).toNumber === 100);
// })

it('should NOT allow more than two bets', async () => {
    await contract.bet(0, {from: sponsor, value: 100});

    await expectRevert(
        contract.bet(0, {from: staker, value: 100}),
        "cannot bet more than 2 times, as pot size is capped at double betSize"
    );
})

it('should NOT allow anyone other than judge to approve', async () => {
    await expectRevert(
        contract.approve(0, 1, {from: staker}),
        "only judge can approve"
    )
})

it('should NOT allow more than two deicsion outcomes', async () => {
    await expectRevert(
        contract.approve(0, 3, {from: judge}),
        "decision is either 1 for SUCCEESS or 2 for FAILURE"
    )
})

it('should approve correctly', async () => {
    await contract.approve(0, 1, {from: judge});
    const goal = await contract.goals(0);

    assert(goal.outcome.toNumber() === 0);
    assert(goal.state.toNumber() === 3);
})

// it('staker should have won 2 * betSize - gas cost', async () => {

// }) // Will need to figure this one out

it('should NOT allow approve unless state is in BETTING', async () => {
    await expectRevert(
        contract.approve(0, 1, {from: judge}),
        "state must be in BETTING"
    )
})

});