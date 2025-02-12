const deployToken = async(hre) => {
    const { deploy } = hre.deployments;
    const { deployer } = await hre.getNamedAccounts();

    console.log("deployer: ", deployer);

    await deploy("Institution", {
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
    const institution = await hre.deployments.get('Institution');
    console.log("-> Institution address: ", institution.address);
};

module.exports = deployToken;
deployToken.tags = ["Token"];