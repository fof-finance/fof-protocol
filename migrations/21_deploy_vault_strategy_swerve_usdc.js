const Controller = artifacts.require('Controller');
const Vault = artifacts.require('Vault');
const StrategySwerveUSD = artifacts.require('StrategySwerveUSD');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    Vault,
    '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    Controller.address);
  await deployer.deploy(
    StrategySwerveUSD,
    1,
    Controller.address);
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setVault(
    '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    Vault.address);
  await contractInstance.setStrategy(
    '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    StrategySwerveUSD.address);
};
