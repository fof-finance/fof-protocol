require('dotenv-flow').config();
const HDWalletProvider = require('@truffle/hdwallet-provider');
const testnetMnemonic = process.env.TESTNET_MNEMONIC;
const mainnetMnemonic = process.env.MAINNET_MNEMONIC;
const gasPrice = process.env.GAS_PRICE;
const ropstenInfura = 'https://ropsten.infura.io/v3/5ce8fba73cc94be581a3c488ebd5efee';
const kovanInfura = 'https://kovan.infura.io/v3/5ce8fba73cc94be581a3c488ebd5efee';
const mainnetInfura = 'https://mainnet.infura.io/v3/5ce8fba73cc94be581a3c488ebd5efee';

module.exports = {
  // Uncommenting the defaults below 
  // provides for an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  
  networks: {
   development: {
     host: '127.0.0.1',
     port: 7545,
     network_id: '*'
   },
   ropsten: {
    provider: function() {
      return new HDWalletProvider(testnetMnemonic, ropstenInfura);
    },
    network_id: 3,
    gas: 6000000
   },
   kovan: {
    provider: function() {
      return new HDWalletProvider(testnetMnemonic, kovanInfura);
    },
    network_id: 42,
    gas: 6000000
   },
   mainnet: { // 发布前需要根据当前主网燃气费修改配置
    provider: function() {
      return new HDWalletProvider(mainnetMnemonic, mainnetInfura);
    },
    network_id: 1,
    gasPrice: gasPrice,
    gas: 6000000
   }
  }

};