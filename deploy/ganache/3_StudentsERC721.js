const deployToken = async (hre) => {
    const { deploy } = hre.deployments;
    const { deployer } = await hre.getNamedAccounts();
    const institution = await hre.deployments.get('Institutions');
    console.log("institution address: ", institution.address);
  
    await deploy("StudentsERC721", {
      from: deployer,
      args: [],
      log: true,
      proxy: {
        proxyContract: "OpenZeppelinTransparentProxy",
        viaAdminContract: "DefaultProxyAdmin",
        execute: {
          init: {
            methodName: "initialize",
            args: [institution.address],
          },
        },
      },
    });
  };
  module.exports = deployToken;
  deployToken.tags = ["Token"];
  