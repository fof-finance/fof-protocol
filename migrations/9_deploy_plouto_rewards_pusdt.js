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
    '0xD2fA9DaA3be5B30913b883fD76d27eF3e4cB351c',
    PLU.address);
};
