const Controller = artifacts.require('Controller');
const StrategyCurveYCRVVoter = artifacts.require('StrategyCurveYCRVVoter');

module.exports = async function(deployer, network) {
  await deployer;
  await deployer.deploy(
    StrategyCurveYCRVVoter,
    Controller.address);
  const contractInstance = await deployer.deploy(Controller, { overwrite: false });
  await contractInstance.setStrategy(
    '0xdf5e0e81dff6faf3a7e52ba697820c5e32d806a8',
    StrategyCurveYCRVVoter.address);
};
