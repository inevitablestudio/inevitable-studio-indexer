const deployToken = async (hre) => {
    const { deploy } = hre.deployments;
    const { deployer } = await hre.getNamedAccounts();
  
    await deploy("Token", {
      from: deployer,
      args: [],
      log: true,
      proxy: {
        proxyContract: "OpenZeppelinTransparentProxy",
        viaAdminContract: "DefaultProxyAdmin",
        execute: {
          init: {
            methodName: "initialize",
            args: [100],
          },
        },
      },
    });
  };
  module.exports = deployToken;
  deployToken.tags = ["Token"];
  