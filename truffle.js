const HDWalletProvider = require("truffle-hdwallet-provider-privkey");

var secrets = require('./secrets.json')

module.exports = {
 	networks: {
 		development: {
 			host: '127.0.0.1',
 			port: 8545,
 			network_id: '*',
 			gas: 4700000,
 		},
        rinkeby: {
            provider: () => { return new HDWalletProvider([secrets.secret], "https://rinkeby.infura.io/" + secrets.api_key)},
            network_id: 4,
            gas: 4700000,
            gasPrice: 20000000000
        },
 	},
 	solc: {
 		optimizer: {
 			enabled: true,
 			runs: 200,
 		},
 	},
 	migrations_directory: './migrations',
 }
