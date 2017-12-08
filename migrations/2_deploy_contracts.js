var IHTTokenFive = artifacts.require("./IHTTokenFive.sol");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(IHTTokenFive, 1512372600, 1512460800, {gas: 5000000}).then(
    function() {
      var instance = IHTTokenFive.deployed();
      return instance;
    }).then(
      function(instance){
          console.log("Token instance: ", instance);
      });
}
