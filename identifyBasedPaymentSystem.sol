// SPDX-License-Identifier: MIT
pragma solidity = 0.8.19;

import "../interfaces/IProofOfIdentity.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
 
/**
 * @title IdentityBasedPaymentSystemPOI
 * @author Abdul
 * @dev Example implementation of using the Proof of Identity contract for institution 
 * payment system where staff will recieve their salary by calling getPaid() function
 * and students can pay their fee easily by simply calling payFee() function.
*/
contract IdentityBasedPaymentSystemPOI is AccessControl{

    /* STATE VARIABLES
    ==================================================*/
    /**
     * @dev For student account type is 1.
     */
    uint8 private constant _Student = 1;

    /**
     * @dev For staff(Workers,Teachers) account type is 2.
     */
    uint8 private constant _Staff = 2;

    /**
     * @dev Fee amount will be stored.
     */
    uint256 private _Fee;

    /**
     * @dev Salary amount will be stored.
     */
    uint256 private _Salary;

    /**
     * @dev current month.
     */
    uint8 private _CurrentMonth;

    /**
     * @dev current year.
     */
    uint8 private _CurrentYear;

    /**
     * @dev mapping to verify fee paid or not.
     * mapping will get address of the student, uint8 
     * for month and uint8 for year
     * returns bool shows paid fee or not.
     */
    mapping(address => mapping(uint8 => mapping(uint8 => bool))) private _isFeePaid;     

    /**
     * @dev mapping to verify got paid or not.
     * mapping will get address of the staff, uint8 
     * for month and uint8 for year
     * returns bool shows got paid or not.
     */
    mapping(address => mapping(uint8 => mapping(uint8 => bool))) private _isGotPaid;     

    /**
     * @dev The Proof of Identity Contract.
     */
    IProofOfIdentity private _proofOfIdentity;

    /* EVENTS
    ==================================================*/
    /**
     * @notice Emits the updated fee amount.
     * @param amount The updated amount of fee.
     */
    event FeeUpdated(uint256 indexed amount);

    /**
     * @notice Emits the updated salary amount.
     * @param amount The updated amount of salary.
     */
    event SalaryUpdated(uint256 indexed amount);

    /**
     * @notice Emits the updated month.
     * @param month The updated number of month.
     */
    event CurrentMonthUpdated(uint256 indexed month);

    /**
     * @notice Emits the updated month.
     * @param year The updated number of month.
     */
    event CurrentYearUpdated(uint256 indexed year);

    /**
     * @notice Emits the new Proof of Identity contract address.
     * @param poiAddress The new Proof of Identity contract address.
     */
    event POIAddressUpdated(address indexed poiAddress);

    /**
     * @notice Emits to remind to pay fee.
     */
    event PayFeeOnTime();    
    
    /* ERRORS
    ==================================================*/
    /**
     * @notice Error to throw when the zero address has been supplied and it
     * is not allowed.
     */
    error IdentityBasedPaymentSystemPOI__ZeroAddress();

    /**
     * @notice Error to throw when an attribute has expired.
     * @param expiry The expiry
     */
    error IdentityBasedPaymentSystemPOI__AttributeExpired(uint256 expiry);
    
    /**
     * @notice Error to throw when value is zero.
     */
    error ZeroValue();

    /**
     * @notice Error to throw when value is not equal to fee.
     */
    error ValueShouldBeEqualToFee();

    /**
     * @notice Error to throw when fee already paid.
     */
    error FeeAlreadyPaid();

    /**
     * @notice Error to throw when already got paid.
     */
    error AlreadyGotPaid();

    /**
     * @notice Error to throw when other then student calls.
     */
    error OnlyStudent();  

    /**
     * @notice Error to throw when student was suspended.
     */
    error SuspendedStudent();    

    /**
     * @notice Error to throw when other then staff calls.
     */
    error OnlyStaff();  

    /**
     * @notice Error to throw when staff was suspended.
     */
    error SuspendedStaff();   

    /**
     * @notice Error to throw when month is greater then 12 or 0.
     */
    error NotMonth();

    /**
     * @notice Error to throw when year is wrong.
     */
    error NotYear();

    /* CONSTRUCTOR
    ==================================================*/
    /**
     * @param admin The address of the admin.
     * @param poi The address of the Proof of Identity contract.
     * @param fee Fee amount.
     * @param salary Salary amount.
     * @param CurrentMonth Current month number.
     */
    constructor(
        address admin,
        address poi, 
        uint256 fee, 
        uint256 salary,
        uint8 CurrentMonth,
        uint8 CurrentYear
        )
        
        {
        require(admin != address(0), "Invalid admin address");

        _setupRole(DEFAULT_ADMIN_ROLE,admin);
        setPOIAddress(poi);
        setFee(fee);
        setSalary(salary);
        setCurrentMonth(CurrentMonth);
        setCurrentYear(CurrentYear);
    } 

    /* FUNCTIONS
    ==================================================*/
    /**
     * @notice Allow staff to get paid.
     * @dev May revert with `OnlyStaff`
     * May revert with `AlreadyGotPaid`.
     * May revert with `SuspendedStaff`.s
     */
    function getPaid() public {
        if(_checkUserType(msg.sender) == _Staff) revert OnlyStaff();
        if(_isGotPaid[msg.sender][_CurrentMonth][_CurrentYear] == true) revert AlreadyGotPaid();
        if(_isSuspended(msg.sender)) revert SuspendedStaff();

        (bool sent,) = msg.sender.call{value : _Salary}("");
        require(sent, 'Failed to send Ether');

        
        _isGotPaid[msg.sender][_CurrentMonth][_CurrentYear] = true;
    }

    /**
     * @notice Receives fee from students.
     * @dev May revert with `OnlyStudent`
     * May revert with `SuspendedStudent`.
     * May revert with `FeeAlreadyPaid`.
     * May revert with `ValueShouldBeEqualToFee`.
     */
    function payFee() public payable {
        if(_checkUserType(msg.sender) == _Student) revert OnlyStudent();
        if(_isSuspended(msg.sender)) revert SuspendedStudent();
        if(_isFeePaid[msg.sender][_CurrentMonth][_CurrentYear] == true) revert FeeAlreadyPaid();
        if(msg.value != _Fee) revert ValueShouldBeEqualToFee();

        _isFeePaid[msg.sender][_CurrentMonth][_CurrentYear] = true;
    }

    /**
     * @notice Returns the fee amount.
     * @return The amount of fee.
     */
    function getFee() public view returns(uint256){
        return _Fee;
    }

    /**
     * @notice Updates the _CurentMonth.
     * @param CurrentMonth The new month.
     * @dev May revert with:
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     * May revert with `ZeroAmount`.
     * May emit a `CurrentMonthUpdated` event.
     */
    function setCurrentMonth(uint8 CurrentMonth) public onlyRole(DEFAULT_ADMIN_ROLE) {
        
        if (CurrentMonth == 0 && CurrentMonth<13) revert NotMonth();

        _CurrentMonth = CurrentMonth;
        emit CurrentMonthUpdated(CurrentMonth);
        emit PayFeeOnTime();
    }

    /**
     * @notice Returns the value of _CurrentMonth.
     * @return _CurrentMonth.
     */
    function getCurrentMonth() public view returns(uint256){
        return _CurrentMonth;
    }

    /**
     * @notice Updates the _CurentYear.
     * @param CurrentYear The new year.
     * @dev May revert with:
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     * May revert with `ZeroAmount`.
     * May emit a `CurrentYearUpdated` event.
     */
    function setCurrentYear(uint8 CurrentYear) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (CurrentYear <= 2022) revert NotYear();
        _CurrentYear = CurrentYear;
        emit CurrentYearUpdated(CurrentYear);
    }

    /**
     * @notice Returns the value of _CurrentMonth.
     * @return _CurrentMonth.
     */
    function getCurrentYear() public view returns(uint256){
        return _CurrentYear;
    }

    /**
     * @notice Updates the fee amount.
     * @param fee The new fee amount.
     * @dev May revert with:
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     * May revert with `ZeroFeeAmount`.
     * May emit a `FeeUpdated` event.
     */
    function setFee(uint256 fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (fee == 0) revert ZeroValue();

        _Fee = fee;
        emit FeeUpdated(fee);
    }

        /**
     * @notice Updates the salary amount.
     * @param salary The new salary amount.
     * @dev May revert with:
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     * May revert with `ZeroValue`.
     * May emit a `SalaryUpdated` event.
     */
    function setSalary(uint256 salary) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (salary == 0) revert ZeroValue();

        _Salary = salary;
        emit SalaryUpdated(salary);
    }

    /**
     * @notice Sets the Proof of Identity contract address.
     * @param poi The address for the Proof of Identity contract.
     * @dev May revert with:
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     * May revert with `SimpleStoragePOI__ZeroAddress`.
     * May emit a `POIAddressUpdated` event.
     */
    function setPOIAddress(address poi) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (poi == address(0)) revert IdentityBasedPaymentSystemPOI__ZeroAddress();

        _proofOfIdentity = IProofOfIdentity(poi);
        emit POIAddressUpdated(poi);
    }

    /**
     * @notice Returns whether an account is suspended.
     * @param account The account to check.
     * @return True if the account is suspended, false otherwise.
     */
    function _isSuspended(address account) private view returns (bool) {
        return _proofOfIdentity.isSuspended(account);
    }

    /**
     * @notice Validates that a given `expiry` is greater than the current
     * `block.timestamp`.
     *
     * @param expiry The expiry to check.
     *
     * @return True if the expiry is greater than the current timestamp, false
     * otherwise.
     */
    function _validateExpiry(uint256 expiry) private view returns (bool) {
        return expiry > block.timestamp;
    }

    /**
     * @notice Helper function to check whether a given `account`'s `userType`
     * is valid.
     *
     * @param account The account to check.
     *
     * @return type The occount's type.
     *
     * @dev For a `userType` to be valid, it must:
     * -    not be expired;
     */
    function _checkUserType(address account) private view returns (uint256) {
        (uint256 user, uint256 exp, ) = _proofOfIdentity.getUserType(account);
        if (!_validateExpiry(exp)) revert IdentityBasedPaymentSystemPOI__AttributeExpired(exp);
        return user;
    }

    /**
     * @notice Returns the address of the Proof of Identity contract.
     * @return The Proof of Identity address.
     */
    function getPOIAddress() public view returns (address) {
        return address(_proofOfIdentity);
    }

    /**
     * @notice emits the event PayFeeOnTime().
     */
    function feeAlert() private onlyRole(DEFAULT_ADMIN_ROLE){
        emit PayFeeOnTime();
    }
}