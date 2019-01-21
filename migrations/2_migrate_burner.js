/* global artifacts */
var BridgeBurner = artifacts.require("./BridgeBurner.sol");

module.exports = function(deployer) {
  deployer.deploy(BridgeBurner);
};
