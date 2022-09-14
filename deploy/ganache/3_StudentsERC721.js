const deployToken = async(hre) => {
    const { deploy } = hre.deployments;
    const { deployer } = await hre.getNamedAccounts();
    const institution = await hre.deployments.get('Institution');

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
    const studentsERC721 = await hre.deployments.get('StudentsERC721');
    console.log("-> StudentsERC721 address: ", studentsERC721.address);
};


module.exports = deployToken;
deployToken.tags = ["Token"];