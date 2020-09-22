const Controller = artifacts.require('Controller');
const StrategyDummy = artifacts.require('StrategyDummy');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    StrategyDummy,
    '0xd46ba6d942050d489dbd938a2c909a5d5039a161',
    Controller.address);
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setStrategy(
    '0xd46ba6d942050d489dbd938a2c909a5d5039a161',
    StrategyDummy.address);
};
