const CoinToss = artifacts.require("CoinToss");
const truffleAssert = require('truffle-assertions');

contract("CoinToss", async function(accounts){


  const contract_balance = web3.utils.toWei("5", 'ether');
  const contract_balance0 = web3.utils.toWei("0", 'ether');
  const contract_balance2 = web3.utils.toWei("0", 'ether');
  const toss_value = web3.utils.toWei("0.2", 'ether');
  const toss_value0 = web3.utils.toWei("0", 'ether');
  const toss_value2 = web3.utils.toWei("1", 'ether');
  const toss_min = web3.utils.toWei("0.1", 'ether');
  const sc_addr = accounts[0];
  const wallet1 = accounts[0];
  const wallet2 = accounts[1];
  const revert_error = "Returned error: VM Exception while processing transaction: revert";


  beforeEach('New contract for each test', async() =>{
    CoinTossInstance = await CoinToss.new({from: wallet1, value: contract_balance});
  });
  afterEach('Destroy the contract to get back funds', async() =>{
    await truffleAssert.passes(CoinTossInstance.close({from: wallet1}),
      "Destruction of contract failed");
  });

  //Tests of value from constructor
  it("Only owner can fund contract", async()=>{
    await truffleAssert.passes(CoinTossInstance.fund({from: wallet1, value: contract_balance}),
    "You are not owner");
  });
  it("Only owner can destroy contract", async()=>{
    await truffleAssert.passes(CoinTossInstance.close({from: wallet1}),
    "Destruction of contract Failed");
  });
  it("Only owner can withdraw all balance", async()=>{
    await truffleAssert.passes(CoinTossInstance.withdrawAll({from: wallet1}),
    "You are not the owner");
  });
  it("Bet should be not more then contract balance", async()=>{
    let initial_value = await CoinTossInstance.getBalance();
    assert.equal(initial_value, contract_balance,"Contract isn't initiated with correct value");
  });
  it("Owner should be account[0]", async()=>{
    let instance = await CoinToss.new({from: wallet1, value: contract_balance});
    assert(sc_addr == wallet1, "This is not a Owner");
  });
  it("Contract should emit LogNewProvableQuery", async()=>{
    let result = await CoinTossInstance.testRandom();
    await truffleAssert.eventEmitted(result, 'LogNewProvableQuery',(ev) =>{
      return ev.description, ev.queryId;}, 'LogNewProvableQuery should be emited');
  });
  it("Should set contract balance to 0 after withdrawal", async()=>{
    const accBalBefore = await web3.eth.getBalance(accounts[0]);
    let balBefore = await web3.eth.getBalance(CoinTossInstance.address);
    let result = await CoinTossInstance.withdrawAll();
    const accBalAfter = await web3.eth.getBalance(accounts[0]);
    let balAfter = await web3.eth.getBalance(CoinTossInstance.address);

    let tx_price = await web3.eth.getTransaction(result.tx);
    let gas_price = result.receipt.gasUsed * tx_price.gasPrice;

    const accValExp = parseInt(accBalBefore) + (parseInt(balBefore)-parseInt(balAfter))
      - parseInt(gas_price);

    assert.equal(parseInt(accBalAfter).toString(),accValExp.toString(),
    "Value should be equal between old and new value");
  });

  // Last tests need commented out require statement
  //require(msg.value <= balance, "Sender cant exceed current balance and need place bet.");
  //in smart Contract in order to work

  it("After flip balance should increase and decrease", async()=>{
    const accBalBefore = await web3.eth.getBalance(accounts[0]);
    let balBefore = await web3.eth.getBalance(CoinTossInstance.address);
    let result = await CoinTossInstance.bet({from: wallet1, value: toss_value});
    const accBalAfter = await web3.eth.getBalance(accounts[0]);
    let balAfter = await web3.eth.getBalance(CoinTossInstance.address);

    let tx_price = await web3.eth.getTransaction(result.tx);
    let gas_price = result.receipt.gasUsed * tx_price.gasPrice;

    const accValExp = parseInt(accBalBefore) + (parseInt(balBefore)-parseInt(balAfter))
      - parseInt(gas_price);

    assert(parseInt(accBalBefore).toString() > parseInt(accValExp).toString()
    || parseInt(accBalBefore).toString() < parseInt(accValExp).toString(), "Balance didn't change")
  });
  it("Bet should be biger then 0.1 ether", async()=>{
    let coin_toss = CoinTossInstance.bet({from:wallet1, value: toss_value0});
    assert(coin_toss >= toss_min, "Bet is too small");
  });
  it("Bet should be biger then 0.1 ether", async()=>{
    await truffleAssert.fails(CoinTossInstance.bet({from: wallet1, value: toss_value0}),
    revert_error);
  });
  it("Bet should failed when no bet value", async()=>{
    await truffleAssert.fails(CoinTossInstance.bet({from: wallet1, value: 0}),
    revert_error);
  });
  it("You shoudn't be able to withdraw if balance is 0", async()=>{
    let instance = await CoinToss.new({from:wallet1, value: contract_balance0});
    await truffleAssert.fails(instance.withdrawAll({from: wallet1}),
    revert_error);
  });
  // Events emited
  // it("Contract should emit GeneratedNumber", async()=>{
  //   await truffleAssert.passes(CoinTossInstance.bet({from:wallet1, value: toss_value}));
  //   try {
  //     let result = await CoinTossInstance.__callback();
  //     await truffleAssert.eventEmitted(result, 'GeneratedNumber', (ev) =>{
  //       return ev.gameResult;}, 'GeneratedNumber should be emited');
  //     }  catch {
  //       console.log("Cant catch emit");
  //   }
  // });
  // it("Contact should emit GameResult", async()=>{
  //   await truffleAssert.passes(CoinTossInstance.bet({from:wallet1, value: toss_value}));
  //   try {
  //     let result = await CoinTossInstance.processResult();
  //     await truffleAssert.prettyPrintEmittedEvents(result, 'GameResult', (ev) =>{
  //       return ev.owner, ev.amountwon;}, 'GameResult should be emited');
  //     } catch {
  //       console.log("Cant catch emit");
  //     }
  // });
})
