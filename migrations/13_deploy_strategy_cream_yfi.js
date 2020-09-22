const Controller = artifacts.require('Controller');
const StrategyCreamYFI = artifacts.require('StrategyCreamYFI');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    StrategyCreamYFI,
    Controller.address);
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setStrategy(
    '0x0bc529c00c6401aef6d220be8c6ea1667f6ad93e',
    StrategyCreamYFI.address);
};
