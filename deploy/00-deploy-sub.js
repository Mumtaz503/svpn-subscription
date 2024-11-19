const { network, ethers } = require("hardhat");
const { networkConfig, developmentChains } = require("../helper-hardhat.confg");
const { verify } = require("../utils/verification");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  log("-------------------------------------------------");
  log("Deploying SVPN_Subscription...");

  const constructorArgs = [
    "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",
    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
    5,
    10,
    10,
    20,
    30,
  ];

  const svpnSub = await deploy("SVPN_Subscription", {
    from: deployer,
    log: true,
    args: constructorArgs,
    waitConfirmations: network.config.blockConfirmations || 1,
    gasLimit: 6000000,
  });

  if (!developmentChains.includes(network.name)) {
    await verify(rental.address, constructorArgs);
  }
  log("-------------------------------------------------");
  log("successfully deployed ID_generator...");
};

module.exports.tags = ["all", "svpn"];
