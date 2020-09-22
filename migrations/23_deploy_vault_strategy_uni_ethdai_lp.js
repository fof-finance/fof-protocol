const Controller = artifacts.require('Controller');
const Vault = artifacts.require('Vault');
const StrategyUniLPStaking = artifacts.require('StrategyUniLPStaking');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    Vault,
    '0xa478c2975ab1ea89e8196811f51a7b7ade33eb11',
    Controller.address);
  await deployer.deploy(
    StrategyUniLPStaking,
    '0xa478c2975ab1ea89e8196811f51a7b7ade33eb11',
    '0xa1484C3aa22a66C62b77E0AE78E15258bd0cB711',
    Controller.address);
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setVault(
    '0xa478c2975ab1ea89e8196811f51a7b7ade33eb11',
    Vault.address);
  await contractInstance.setStrategy(
    '0xa478c2975ab1ea89e8196811f51a7b7ade33eb11',
    StrategyUniLPStaking.address);
};
