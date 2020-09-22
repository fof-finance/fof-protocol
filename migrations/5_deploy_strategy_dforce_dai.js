const Controller = artifacts.require('Controller');
const StrategyDForce = artifacts.require('StrategyDForce');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    StrategyDForce,
    '0x6B175474E89094C44Da98b954EedeAC495271d0F',
    '0x02285AcaafEB533e03A7306C55EC031297df9224',
    '0xD2fA07cD6Cd4A5A96aa86BacfA6E50bB3aaDBA8B',
    Controller.address);
  if (network.includes('ropsten')) {
    const contractInstance = await deployer.deploy(Controller, { overwrite: false });
    await contractInstance.setStrategy(
      '0xADeD4B66783099E174a17b74E698aeFA0fd8f19d',
      StrategyDForce.address);
    return;
  } else if (network.includes('kovan')) {
    const contractInstance = await deployer.deploy(Controller, { overwrite: false });
    await contractInstance.setStrategy(
      '0x5075a70f5c86a4132e57fcea857c0c1d87e43093',
      StrategyDForce.address);
    return;
  }
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setStrategy(
    '0x6b175474e89094c44da98b954eedeac495271d0f',
    StrategyDForce.address);
};
