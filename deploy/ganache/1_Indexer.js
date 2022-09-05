const deployToken = async (hre) => {
    const { deploy } = hre.deployments;
    const { deployer } = await hre.getNamedAccounts();
  
    await deploy("Indexer", {
      from: deployer,
      args: [],
      log: true,
      proxy: {
        proxyContract: "OpenZeppelinTransparentProxy",
        viaAdminContract: "DefaultProxyAdmin",
        execute: {
          init: {
            methodName: "initialize",
            args: [],
          },
        },
      },
    });
    const indexer = await hre.deployments.get('Indexer');
    console.log("-> Indexer address: ", indexer.address);
  };

  module.exports = deployToken;
  deployToken.tags = ["Token"];
  