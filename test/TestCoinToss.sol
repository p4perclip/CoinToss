pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";

import "../contracts/CoinToss.sol";

contract TestCoinToss {
  CoinToss coinTossInst = CoinToss(DeployedAddresses.CoinToss());
}
