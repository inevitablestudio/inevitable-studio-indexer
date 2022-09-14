// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./StudentsERC721.sol";

contract Institution is Initializable, PausableUpgradeable, AccessControlUpgradeable {
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

    bytes4 public constant INSTITUTION_INTERFACE_ID = 0x494e5354;
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
    CountersUpgradeable.Counter public courseCounter;
    CountersUpgradeable.Counter public activeCourseCounter;

    struct Student {
        uint256 id;
        bool isActive;
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

    function getCourse(uint256 courseId) public view returns (Course memory) {
        return courses[courseId];
    }
    
    // Student management
    function registerStudent(uint256 courseId, address student) 
    public 
    onlyRole(MINTER_ROLE) 
    onlyActiveCourse(courseId) 
    onlyInactiveStudent(courseId, student)
    nonZero(student) {
        uint256 studentId = StudentsERC721(studentsERC721).safeMint(student, courses[courseId].baseURI);
        students[courseId][student].id = studentId;
        students[courseId][student].isActive = true;
        courses[courseId].activeStudentsBalance += 1;
        courses[courseId].studentsBalance += 1;
        studentCounter.increment();
        
        emit StudentRegistered(courseId, studentId, student);
    }

    function unregisterStudent(uint256 courseId, address student) public onlyRole(MINTER_ROLE) onlyActiveStudent(courseId, student) {
        students[courseId][student].isActive = false;
        courses[courseId].activeStudentsBalance -= 1;

        emit StudentUnregistered(courseId, students[courseId][student].id, student);
    }

    function getStudentId(uint256 courseId, address student) public view onlyActiveStudent(courseId, student) returns (uint256) {
        return students[courseId][student].id;
    }

    function getStudentURI(uint256 courseId, address student) public view onlyActiveStudent(courseId, student) returns (string memory) {
        return StudentsERC721(studentsERC721).tokenURI(students[courseId][student].id);
    }

    function getAllStudentIds(address student) public view returns (uint256[] memory) {
        uint256 studentBalance = StudentsERC721(studentsERC721).balanceOf(student);
        uint256[] memory tokensIds;
        for (uint i = 0; i < studentBalance; i++) {
            tokensIds[i] = StudentsERC721(studentsERC721).tokenOfOwnerByIndex(student, i);
        }
        return tokensIds;
    }

    function getAllStudentURIs(address student) public view returns (string[] memory) {
        uint256[] memory studentIds = getAllStudentIds(student);
        string[] memory tokensURI;
        for (uint i = 0; i < studentIds.length; i++) {
            tokensURI[i] = StudentsERC721(studentsERC721).tokenURI(studentIds[i]);
        }
        return tokensURI;
    }

    // Helper functions
    function setStudentsERC721(address _studentsERC721) onlyRole(DEFAULT_ADMIN_ROLE) public {
        require(
            ERC165Upgradeable(_studentsERC721).supportsInterface(INTERFACE_ERC721),
            "Contract must derive from ERC721"
        );
        studentsERC721 = _studentsERC721;
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
        return super.supportsInterface(interfaceId) || interfaceId == INSTITUTION_INTERFACE_ID;
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

    modifier onlyActiveStudent(uint256 courseId, address studentId) {
        require(students[courseId][studentId].isActive, "Student not registered");
        _;
    }

    modifier onlyInactiveStudent(uint256 courseId, address studentId) {
        require(!students[courseId][studentId].isActive, "Student already registered");
        _;
    }
}
