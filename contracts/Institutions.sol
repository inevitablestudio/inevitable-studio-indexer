// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "./StudentsERC721.sol";

contract Institutions is Initializable, PausableUpgradeable, AccessControlUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes4 public constant INSTITUTIONS_INTERFACE_ID = 0x494e5354;
    bytes4 public constant INTERFACE_ERC721 = 0x80ac58cd;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public baseURI;
    address public studentsERC721;

    struct Course {
        bool isActive;
        string baseURI;
        uint256 activeStudentsBalance;
    }
    mapping(uint256 => Course) public courses;
    mapping(string => bool) public baseURIExists;
    CountersUpgradeable.Counter public courseCounter;

    struct Student {
        uint256 id;
        bool isCertified;
    }
    mapping(uint256 => mapping(address => Student)) public students;
    CountersUpgradeable.Counter public studentCounter;

    constructor() {
        // _disableInitializers();
    }

    function initialize() initializer public {
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    // Courses management
    function registerCourse(string memory _baseURI) public onlyRole(MINTER_ROLE) onlyUniqueBaseURI(_baseURI) {
        courses[courseCounter.current()].activeStudentsBalance = 0;
        courses[courseCounter.current()].isActive = true;
        courses[courseCounter.current()].baseURI = _baseURI;
        courseCounter.increment();
    }

    function unregisterCourse(uint256 courseId) public onlyRole(MINTER_ROLE) onlyActiveCourse(courseId) {
        courses[courseId].isActive = false;
    }

    function getCourseURI(uint256 courseId) public view returns (string memory) {
        return courses[courseId].baseURI;
    }
    
    // Student management
    function registerStudent(uint256 courseId, address student) 
    public 
    onlyRole(MINTER_ROLE) 
    onlyActiveCourse(courseId) 
    onlyUncertifiedStudent(courseId, student)
    nonZero(student) {
        require(!students[courseId][student].isCertified, "Student already registered");
        students[courseId][student].id = studentCounter.current();
        students[courseId][student].isCertified = true;
        studentCounter.increment();
        courses[courseId].activeStudentsBalance += 1;
    }

    function unregisterStudent(uint256 courseId, address student) public onlyRole(MINTER_ROLE) onlyCertifiedStudent(courseId, student) {
        students[courseId][student].isCertified = false;
        courses[courseId].activeStudentsBalance -= 1;
    }

    function getStudentCertificate(uint256 courseId, address student) 
    public view 
    nonZero(student) 
    onlyCertifiedStudent(courseId, student) 
    returns (uint256) {
        return StudentsERC721(studentsERC721).tokenOfOwnerByIndex(student, 0);
    }

    function getCertificateId(uint256 courseId, address student) public view returns (uint256) {
        uint256 certificatesBalance = StudentsERC721(studentsERC721).balanceOf(student);
        for (uint i = 0; i < certificatesBalance; i++) {
            uint256 certificateId = StudentsERC721(studentsERC721).tokenOfOwnerByIndex(student, i);
            string memory tokenURI = StudentsERC721(studentsERC721).tokenURI(certificateId);
            string memory localCertificateURI = getCertificateURI(courseId, certificateId);
            if (keccak256(abi.encodePacked(localCertificateURI)) == keccak256(abi.encodePacked((tokenURI)))) {
                return certificateId;
            }
        }
        revert("Student has no certificate");
    }

    function getCertificateURI(uint256 certificateId) public view returns (string memory) {
        return StudentsERC721(studentsERC721).tokenURI(certificateId);
    }

    function getAllCertificatesIds(address student) public view returns (uint256[] memory) {
        uint256 certificatesBalance = StudentsERC721(studentsERC721).balanceOf(student);
        uint256[] memory tokensIds;
        for (uint i = 0; i < certificatesBalance; i++) {
            tokensIds[i] = StudentsERC721(studentsERC721).tokenOfOwnerByIndex(student, i);
        }
        return tokensIds;
    }

    function getAllCertificatesURIs(address student) public view returns (string[] memory) {
        uint256[] memory certificatesIds = getAllCertificatesIds(student);
        string[] memory tokensURI;
        for (uint i = 0; i < certificatesIds.length; i++) {
            tokensURI[i] = StudentsERC721(studentsERC721).tokenURI(certificatesIds[i]);
        }
        return tokensURI;
    }

    function certifyStudent(uint256 courseId, address student) 
    public
    nonZero(student) 
    onlyActiveCourse(courseId)
    onlyUncertifiedStudent(courseId, student)
    onlyRole(MINTER_ROLE) {
        StudentsERC721(studentsERC721).safeMint(student, courses[courseId].baseURI);
        courses[courseId].activeStudentsBalance += 1;
    }

    // Helper functions
    function setStudentsERC721(address _studentsERC721) onlyRole(DEFAULT_ADMIN_ROLE) public {
        require(
            IERC165(_studentsERC721).supportsInterface(INTERFACE_ERC721),
            "Contract must derive from ERC721"
        );
        studentsERC721 = _studentsERC721;
    }

    function getCertificateURI(uint courseId, uint256 certificateURI) internal view onlyRole(DEFAULT_ADMIN_ROLE) returns (string memory) {
        return string(abi.encodePacked(courses[courseId].baseURI, Strings.toString(certificateURI)));
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || interfaceId == INSTITUTIONS_INTERFACE_ID;
    }

    // Modifiers
    modifier nonZero(address _address) {
        require(_address != address(0), "Zero address");
        _;
    }

    modifier onlyActiveCourse(uint256 courseId) {
        require(courses[courseId].isActive, "Course inactive");
        _;
    }

    modifier onlyCertifiedStudent(uint256 courseId, address studentId) {
        require(students[courseId][studentId].isCertified, "Student is not certified");
        _;
    }

    modifier onlyUncertifiedStudent(uint256 courseId, address studentId) {
        require(students[courseId][studentId].isCertified, "Student is already certified");
        _;
    }

    modifier onlyUniqueBaseURI(string memory _baseURI) {
        require(!baseURIExists[_baseURI], "Base URI repeated");
        _;
    }
}
