const FRR_CONTRACT = artifacts.require("FRR");

contract("FRR test", async (accounts) => {
    const toWei = (balance) => {
        return web3.utils.toBN(balance * 10 ** 18)
    };
    const BN = (number) => {
        return web3.utils.toBN(number);
    };
    const sleep = (ms) => {
        return new Promise(resolve=>{
            setTimeout(resolve,ms)
        })
    };

    it("1. Deploy FRR", async () => {
        return await FRR_CONTRACT.deployed();
    });

    it("2. transfer FRR", async () => {
        const FRR = await FRR_CONTRACT.deployed();
        return await FRR.transfer(accounts[1], toWei(1));
    });

    it("3. Check All View", async () => {
        const FRR = await FRR_CONTRACT.deployed();
        const FRR_web3 = new web3.eth.Contract(FRR.abi, FRR.address);
        const data = {
            totalSupply: (await FRR_web3.methods.totalSupply().call()).toString(),
            symbol: await FRR_web3.methods.symbol().call(),
            name: await FRR_web3.methods.name().call(),
            decimals: (await FRR_web3.methods.decimals().call()).toString(),
            paused: await FRR_web3.methods.paused().call(),
            owner: await FRR_web3.methods.owner().call(),
            implementation: await FRR_web3.methods.implementation().call(),
        }
        return data;
    });

    it("4. burn test with lock", async () => {
        const FRR = await FRR_CONTRACT.deployed();
        await FRR.burn(toWei(5));
        await FRR.lock(accounts[0], toWei(94), BN(9999999991));
        try{
            await FRR.burn(toWei(1));
        }catch (e){
            console.log("[revert success]", e.message);
        }
        await FRR.unlock(accounts[0], 0);
        await FRR.burn(toWei(1));
    });

    it("5. lock test", async () => {
        const FRR = await FRR_CONTRACT.deployed();

        await FRR.lock(accounts[0], toWei(10), BN(9999999991));
        await FRR.unlock(accounts[0], 0);

        await FRR.lock(accounts[0], toWei(20), BN(9999999992));
        await FRR.lock(accounts[0], toWei(30), BN(9999999993));
        await FRR.unlock(accounts[0], 1);
        await FRR.unlock(accounts[0], 0);

        await FRR.lock(accounts[0], toWei(20), BN(9999999992));
        await FRR.lock(accounts[0], toWei(30), BN(9999999993));
        await FRR.unlock(accounts[0], 0);
        await FRR.unlock(accounts[0], 0);
    });

    it("6. freeze test", async () => {
        const FRR = await FRR_CONTRACT.deployed();
        await FRR.transfer(accounts[1], toWei(1));
        await FRR.freezeAccount(accounts[0]);
        try{
            await FRR.transfer(accounts[1], toWei(1));
        }catch (e){
            console.log("[revert success]", e.message);
        }
        await FRR.unfreezeAccount(accounts[0]);
        await FRR.transfer(accounts[1], toWei(1));
    });

    it("7. pause test", async () => {
        const FRR = await FRR_CONTRACT.deployed();
        await FRR.pause();
        try{
            await FRR.transfer(accounts[1], toWei(1));
        }catch (e){
            console.log("[revert success]", e.message);
        }
        await FRR.unpause();
    });

    it("8. Admin, Owner test", async () => {
        const FRR = await FRR_CONTRACT.deployed();
        await FRR.addAdmin(accounts[1]);
        await FRR.removeAdmin(accounts[1]);
        await FRR.transferOwnership(accounts[1]);
        await FRR.renounceAdmin();
    });

    it("9. auto unlock test", async () => {
        const FRR = await FRR_CONTRACT.deployed();
        const now = Math.floor(new Date().getTime() / 1000);
        const now3seconds = now + 3;

        await FRR.lock(accounts[0], toWei(10), BN(now3seconds));
        sleep(3001);
    });
});