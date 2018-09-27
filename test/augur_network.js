const utils = require('./helpers/utils.js');
const Reverter = require('./helpers/reverter');

contract('AugurAdapter', function (accounts) {
    let reverter = new Reverter(web3);
    afterEach('revert', reverter.revert);

    let token;
    let owner = accounts[0];
    let stranger = accounts[2];

    before('before', async () => {
        await reverter.snapshot();
    })

    after("after", async () => {
    })

    it("TODO", async () => {
    });
});
