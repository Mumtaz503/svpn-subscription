const { expect, assert } = require("chai");
const { developmentChains, testURI } = require("../helper-hardhat.confg");
const { network, getNamedAccounts, ethers, deployments } = require("hardhat");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("svpn unit tests", () => {
      let svpn, deployer, user, userSigner, peiPei, signer, routerV2, provider;
      beforeEach(async () => {
        signer = await ethers.provider.getSigner();
        deployer = (await getNamedAccounts()).deployer;
        user = (await getNamedAccounts()).user;
        userSigner = await ethers.getSigner(user);
        await deployments.fixture(["all"]);
        svpn = await ethers.getContract("SVPN_Subscription", deployer);
        routerV2 = await ethers.getContractAt(
          "UniswapV2Router02",
          "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
          signer
        );
        peiPei = await ethers.getContractAt(
          "IErc20",
          "0x3ffeea07a27fab7ad1df5297fa75e77a43cb5790",
          signer
        );
      });
      describe("Should accept payment and swap", async () => {
        it("Should set the price", async () => {
          const amountOutMin = 0n;
          const path = [
            "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", //weth
            "0x3ffeea07a27fab7ad1df5297fa75e77a43cb5790", //PeiPei
          ];

          const deadline = Math.floor(Date.now() / 1000) + 60 * 10;
          const transactionResponse = await routerV2.swapExactETHForTokens(
            amountOutMin,
            path,
            user,
            deadline,
            {
              value: ethers.parseEther("0.05"),
            }
          );
          await transactionResponse.wait(1);
          const depBal = await peiPei.balanceOf(deployer);
          console.log("deployer balance: ", depBal);
          const usrBal = await peiPei.balanceOf(user);
          console.log("user balance: ", await peiPei.balanceOf(user));
          const transaction = await peiPei
            .connect(userSigner)
            .approve(svpn.target, usrBal);
          await transaction.wait();
          const tx = await svpn
            .connect(userSigner)
            .payForUniqueIDYearly(peiPei.target);
          await tx.wait(1);
          const userInfo = await svpn.getUserInfo(user);
          const depBalAfter = await peiPei.balanceOf(deployer);
          console.log(userInfo);
          console.log("Deployer Balance Before: ", depBal);
          console.log("Deployer Balance After: ", depBalAfter);
          console.log(
            "Yearly payment: ",
            await svpn.getYearlySubscriptionPrice()
          );
          console.log(
            "Monthly Payment: ",
            await svpn.getMonthlySubscriptionPrice()
          );
        });
      });
    });
