const Controller = artifacts.require('Controller');
const StrategySwerveUSD = artifacts.require('StrategySwerveUSD');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    StrategySwerveUSD,
    2,
    Controller.address);
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setStrategy(
    '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    StrategySwerveUSD.address);
};
