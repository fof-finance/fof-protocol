const PLU = artifacts.require('PLU');
const PloutoRewards = artifacts.require('PloutoRewards');

module.exports = async function(deployer, network) {
  await deployer;
  if (network.includes('ropsten')) {
    return;
  } else if (network.includes('kovan')) {
    return;
  }
  await deployer.deploy(
    PloutoRewards,
    '0x5075A70F5C86a4132E57fcEA857C0C1d87e43093',
    PLU.address);
};
