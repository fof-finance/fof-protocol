const PLU = artifacts.require('PLU');
const PulotoGovernance = artifacts.require('PulotoGovernance');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    PulotoGovernance,
    '0x41f15e28A839E73dD7aae5705ad2eBdC0ef98264',
    PLU.address);
};
