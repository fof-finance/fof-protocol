const Controller = artifacts.require('Controller');

module.exports = async function(deployer) {
  await deployer;
  const contractInstance = await deployer.deploy(Controller);
  await contractInstance.setRewards('0x2E44E2F1E79077210914B6D948B1aD0b0cd2b1EC');
};
