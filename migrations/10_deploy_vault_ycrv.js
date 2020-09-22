const Controller = artifacts.require('Controller');
const Vault = artifacts.require('Vault');

module.exports = async function(deployer, network) {
  await deployer;
  if (network.includes('ropsten')) {
    await deployer.deploy(
      Vault,
      '0xADeD4B66783099E174a17b74E698aeFA0fd8f19d',
      Controller.address);
    const contractInstance = await deployer.deploy(Controller, { overwrite: false });
    await contractInstance.setVault(
      '0xADeD4B66783099E174a17b74E698aeFA0fd8f19d',
      Vault.address);
    return;
  } else if (network.includes('kovan')) {
    await deployer.deploy(
      Vault,
      '0x5075a70f5c86a4132e57fcea857c0c1d87e43093',
      Controller.address);
    const contractInstance = await deployer.deploy(Controller, { overwrite: false });
    await contractInstance.setVault(
      '0x5075a70f5c86a4132e57fcea857c0c1d87e43093',
      Vault.address);
    return;
  }
  await deployer.deploy(
    Vault,
    '0xdf5e0e81dff6faf3a7e52ba697820c5e32d806a8',
    Controller.address);
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setVault(
    '0xdf5e0e81dff6faf3a7e52ba697820c5e32d806a8',
    Vault.address);
};
