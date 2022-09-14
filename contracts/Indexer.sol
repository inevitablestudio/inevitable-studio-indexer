// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./Institution.sol";

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

    bytes4 public constant INSTITUTION_INTERFACE_ID = 0x494e5354;

    struct _Institution {
        uint256 id;
        string name;
        bool isActive;
    }
    mapping(address => _Institution) public institutions;
    mapping(uint256 => address) public institutionIdToAddress;
    CountersUpgradeable.Counter public institutionCounter;

    constructor() {
        _disableInitializers();
    }

    // Institution management
    function registerInstitution(address institutionAddress, string memory institutionName) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(ERC165Upgradeable(institutionAddress).supportsInterface(INSTITUTION_INTERFACE_ID), "Contract must implement Institutions interface");
        uint256 institutionId = institutionCounter.current();
        institutions[institutionAddress].id = institutionId;
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

    function getCourse(uint256 institutionId, uint256 courseId) public view returns (Institution.Course memory) {
        return getInstitutionContract(institutionId).getCourse(courseId);
    }

    function getStudentId(uint256 institutionId, uint256 courseId, address student) public view returns (uint256) {
        return getInstitutionContract(institutionId).getStudentId(courseId, student);
    }

    function getStudentURI(uint256 institutionId, uint256 courseId, address student) public view returns (string memory) {
        return getInstitutionContract(institutionId).getStudentURI(courseId, student);
    }

    function getAllStudentIds(uint256 institutionId, address student) public view returns (uint256[] memory) {
        return getInstitutionContract(institutionId).getAllStudentIds(student);
    }

    function getAllStudentURIs(uint256 institutionId, address student) public view returns (string[] memory) {
        return getInstitutionContract(institutionId).getAllStudentURIs(student);
    }

    function getInstitutionContract(uint256 institutionId) internal view returns (Institution) {
        return Institution(institutionIdToAddress[institutionId]);
    }

    modifier onlyActiveInstitution(uint256 institutionId) {
        require(institutions[institutionIdToAddress[institutionId]].isActive, "Institution inactive");
        _;
    }
}
