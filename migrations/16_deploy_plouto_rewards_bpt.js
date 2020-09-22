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
    '0xd5b58830b159d86ddf229a0429817fc7d446b45c',
    PLU.address);
};
