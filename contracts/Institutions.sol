// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "./StudentsERC721.sol";

contract Institutions is Initializable, PausableUpgradeable, AccessControlUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    event CourseRegistered (
        uint256 courseId,
        string courseName
    );

    event CourseUnregistered (
        uint256 courseId,
        string courseName
    );

    event StudentRegistered (
        uint256 courseId,
        uint256 studentId,
        address studentAddress
    );

    event StudentUnregistered (
        uint256 courseId,
        uint256 studentId,
        address studentAddress
    );

    bytes4 public constant INSTITUTIONS_INTERFACE_ID = 0x494e5354;
    bytes4 public constant INTERFACE_ERC721 = 0x80ac58cd;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public studentsERC721;

    struct Course {
        string name;
        bool isActive;
        string baseURI;
        uint256 studentsBalance;
        uint256 activeStudentsBalance;
    }
    // courseId => Course
    mapping(uint256 => Course) public courses;
    mapping(string => bool) public baseURIExists;
    CountersUpgradeable.Counter public courseCounter;

    struct Student {
        uint256 id;
        bool isCertified;
    }
    // courseId => studentAddress => Student
    mapping(uint256 => mapping(address => Student)) public students;
    CountersUpgradeable.Counter public studentCounter;

    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    // Courses management
    function registerCourse(string memory courseBaseURI, string memory courseName) public onlyRole(MINTER_ROLE) {
        require(studentsERC721 != address(0), "StudentsERC721 not defined");
        uint256 courseId = courseCounter.current();
        courses[courseId].studentsBalance = 0;
        courses[courseId].activeStudentsBalance = 0;
        courses[courseId].isActive = true;
        courses[courseId].baseURI = courseBaseURI;
        courses[courseId].name = courseName;
        
        courseCounter.increment();
        activeCourseCounter.increment();

        emit CourseRegistered(courseId, courseName);
    }

    function unregisterCourse(uint256 courseId) public onlyRole(MINTER_ROLE) onlyActiveCourse(courseId) {
        courses[courseId].isActive = false;
        activeCourseCounter.decrement();

        emit CourseUnregistered(courseId, courses[courseId].name);
    }

    function getCourseURI(uint256 courseId) public view returns (string memory) {
        return courses[courseId].baseURI;
    }

    function getCourse(uint256 courseId) public view returns (Course memory) {
        return courses[courseId];
    }
    
    // Student management
    function registerStudent(uint256 courseId, address student) 
    public 
    onlyRole(MINTER_ROLE) 
    onlyActiveCourse(courseId) 
    onlyUncertifiedStudent(courseId, student)
    nonZero(student) {
        require(!students[courseId][student].isCertified, "Student already registered");
        uint256 studentId = StudentsERC721(studentsERC721).safeMint(student, courses[courseId].baseURI);
        students[courseId][student].id = studentId;
        students[courseId][student].isCertified = true;
        studentCounter.increment();
        courses[courseId].activeStudentsBalance += 1;
        courses[courseId].studentsBalance += 1;
        
        emit StudentRegistered(courseId, studentId, student);
    }

    function unregisterStudent(uint256 courseId, address student) public onlyRole(MINTER_ROLE) onlyCertifiedStudent(courseId, student) {
        students[courseId][student].isCertified = false;
        courses[courseId].activeStudentsBalance -= 1;

        emit StudentUnregistered(courseId, students[courseId][student].id, student);
    }

    function getStudentCertificate(uint256 courseId, address student) 
    public view 
    nonZero(student) 
    onlyCertifiedStudent(courseId, student) 
    returns (uint256) {
        return StudentsERC721(studentsERC721).tokenOfOwnerByIndex(student, 0);
    }

    function getCertificateId(uint256 courseId, address student) public view returns (uint256) {
        for (uint i = 0; i < courseCounter.current(); i++) {
            if (students[courseId][student].isCertified) {
                return students[courseId][student].id;
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
        uint256 certificateId = StudentsERC721(studentsERC721).safeMint(student, courses[courseId].baseURI);
        courses[courseId].activeStudentsBalance += 1;
        students[courseId][student].id = certificateId;
    }

    // Helper functions
    function setStudentsERC721(address _studentsERC721) onlyRole(DEFAULT_ADMIN_ROLE) public {
        require(
            ERC165Upgradeable(_studentsERC721).supportsInterface(INTERFACE_ERC721),
            "Contract must derive from ERC721"
        );
        studentsERC721 = _studentsERC721;
    }

    function getCertificateURI(uint courseId, uint256 certificateURI) internal view onlyRole(DEFAULT_ADMIN_ROLE) returns (string memory) {
        return string(abi.encodePacked(courses[courseId].baseURI, StringsUpgradeable.toString(certificateURI)));
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
        _;
    }
}
