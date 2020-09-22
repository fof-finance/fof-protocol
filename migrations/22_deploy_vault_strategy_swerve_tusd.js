const Controller = artifacts.require('Controller');
const Vault = artifacts.require('Vault');
const StrategySwerveUSD = artifacts.require('StrategySwerveUSD');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    Vault,
    '0x0000000000085d4780B73119b644AE5ecd22b376',
    Controller.address);
  await deployer.deploy(
    StrategySwerveUSD,
    3,
    Controller.address);
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setVault(
    '0x0000000000085d4780B73119b644AE5ecd22b376',
    Vault.address);
  await contractInstance.setStrategy(
    '0x0000000000085d4780B73119b644AE5ecd22b376',
    StrategySwerveUSD.address);
};
