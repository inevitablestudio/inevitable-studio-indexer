// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./Institutions.sol";

contract Indexer is Initializable, PausableUpgradeable, AccessControlUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    event InstitutionRegistered (
        uint256 institutionId,
        address institutionAddress, 
        string institutionName
    );

    event InstitutionUnregistered (
        uint256 institutionId,
        address institutionAddress, 
        string institutionName
    );

    bytes4 public constant INSTITUTIONS_INTERFACE_ID = 0x494e5354;

    struct Institution {
        uint256 id;
        bool isActive;
        uint256 activeCoursesBalance;
        string name;
    }
    mapping(address => Institution) public institutions;
    mapping(uint256 => address) public institutionIdToAddress;
    CountersUpgradeable.Counter public institutionCounter;

    constructor() {
        _disableInitializers();
    }

    // Institution management
    function registerInstitution(address institutionAddress, string memory institutionName) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(ERC165Upgradeable(institutionAddress).supportsInterface(INSTITUTIONS_INTERFACE_ID), "Contract must implement Institutions interface");
        uint256 institutionId = institutionCounter.current();
        institutions[institutionAddress].id = institutionId;
        institutions[institutionAddress].activeCoursesBalance = 0;
        institutions[institutionAddress].isActive = true;
        institutions[institutionAddress].name = institutionName;
        institutionIdToAddress[institutionId] = institutionAddress;
        institutionCounter.increment();
        
        emit InstitutionRegistered(institutionId, institutionAddress, institutionName);
    }

    function unregisterInstitution(uint256 institutionId) public onlyRole(DEFAULT_ADMIN_ROLE) onlyActiveInstitution(institutionId) {
        address institutionAddress = institutionIdToAddress[institutionId];
        institutions[institutionAddress].isActive = false;
        
        emit InstitutionUnregistered(institutionId, institutionAddress, institutions[institutionAddress].name);
    }

    function initialize() initializer public {
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getCertificateId(uint256 institutionId, uint256 courseId, address student) internal view returns (uint256) {
        return getInstitutionContract(institutionId).getCertificateId(courseId, student);
    }

    function getCertificateURI(uint256 institutionId, uint256 courseId, address student) internal view returns (string memory) {
        Institutions intitution = getInstitutionContract(institutionId);
        uint256 certificateId = intitution.getCertificateId(courseId, student);
        return intitution.getCertificateURI(certificateId);
    }

    function getAllCertificatesIds(uint256 institutionId, address student) internal view returns (uint256[] memory) {
        return getInstitutionContract(institutionId).getAllCertificatesIds(student);
    }

    function getAllCertificatesURIs(uint256 institutionId, address student) public view returns (string[] memory) {
        Institutions intitution = getInstitutionContract(institutionId);
        uint256[] memory certificatesIds = intitution.getAllCertificatesIds(student);
        string[] memory tokensURI;
        for (uint i = 0; i < certificatesIds.length; i++) {
            tokensURI[i] = intitution.getCertificateURI(certificatesIds[i]);
        }
        return tokensURI;
    }

    function getInstitutionContract(uint256 institutionId) internal view returns (Institutions) {
        address institutionAddress = institutionIdToAddress[institutionId];
        return Institutions(institutionAddress);
    }

    modifier onlyActiveInstitution(uint256 institutionId) {
        require(institutions[institutionIdToAddress[institutionId]].isActive, "Institution inactive");
        _;
    }
}
