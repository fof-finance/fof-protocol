const Controller = artifacts.require('Controller');
const StrategySwerveUSD = artifacts.require('StrategySwerveUSD');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    StrategySwerveUSD,
    0,
    Controller.address);
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setStrategy(
    '0x6b175474e89094c44da98b954eedeac495271d0f',
    StrategySwerveUSD.address);
};
