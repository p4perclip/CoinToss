const CoinToss = artifacts.require("CoinToss");

module.exports = function(deployer) {
  deployer.deploy(CoinToss);
};
