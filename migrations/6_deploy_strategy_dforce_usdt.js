const Controller = artifacts.require('Controller');
const StrategyDForce = artifacts.require('StrategyDForce');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    StrategyDForce,
    '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    '0x868277d475E0e475E38EC5CdA2d9C83B5E1D9fc8',
    '0x324EebDAa45829c6A8eE903aFBc7B61AF48538df',
    Controller.address);
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setStrategy(
    '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    StrategyDForce.address);
};
