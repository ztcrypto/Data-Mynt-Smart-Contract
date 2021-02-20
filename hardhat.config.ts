import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import { HardhatUserConfig } from "hardhat/config";

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  // Your type-safe config goes here
  solidity: "0.6.12",
  networks: {
    hardhat: {
      forking: {
        url:
          "https://eth-mainnet.alchemyapi.io/v2/LaB_5bIY3Oiu_PfG6Crzdev7JKwY44YQ",
      },
    },
    kovan: {
      url:
        "https://eth-kovan.alchemyapi.io/v2/qaFi-8mJMAo1aZMCWJQeimgPsWAu5Tl0",
      accounts: [
        "597ddb29f2c854cdbd115b1117be67f7b19cf6a68b37c91e933dd1e433cee1d2",
      ],
    },
  },
};
export default config;
