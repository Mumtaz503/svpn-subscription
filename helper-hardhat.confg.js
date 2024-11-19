const networkConfig = {
  31337: {
    name: "localhost",
    usdt: "0xdAC17F958D2ee523a2206206994597C13D831ec7", //Mainnet USDT for forked network testing
  },
  11155111: {
    name: "sepolia",
    usdt: "0x080234ABfC2d18A4ac94F7DeE314e28819480e1f", //Simple token
  },
};

const developmentChains = ["hardhat", "localhost"];

module.exports = { networkConfig, developmentChains };
