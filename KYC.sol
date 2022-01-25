// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.9;


contract KYC {

    /** only one admin to monitor, add, remove, modify banks */
    address constant adminAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

    /** struct : Customer
        username (string) - name of the user which is **unique**
        data (string) - customer's data hash
        validatorBank (address) - address of a bank who validated the customer's data
        kycStatus (boolean) - status of kyc submitted 
        downvotes (uint) - number of downvotes
        upvotes (uint) - number of upvotes by other banks than validator bank
    */ 
    struct Customer {
        string username;
        string data;
        address validatorBank;
        bool kycStatus;
        uint256 downvotes;
        uint256 upvotes;
    }

    struct Bank {
        string name;
        address ethAddress;
        string regNumber;
        uint256 complaintsReported;
        uint256 kycCount;
        bool allowedToVote;
    }

    struct KycRequest {
        string username;
        address bankAddress;
        string customerData;
    }

    /** all registered customers
        customerName => Customer struct   
     */
    mapping(string => Customer) public customers;

    /** all registered banks
        bankEthAddress => Bank struct    
     */
    mapping(address => Bank) public banks;

    /** all KYC requests 
        customerName => KycRequest struct
    */
    mapping(string => KycRequest) public requests;

    /** track upvotes and downvotes for customers
        customerName => (voterBankAddress => vote)
        1 - upvote
        2 - downvote
     */
    mapping(string => mapping(address => uint)) public votes;

    /** Total number of registered banks */
    uint256 totalBanks = 0; 

    //modifier: check admin address 
    modifier onlyAdmin {
        require(adminAddress == msg.sender, "Only admin has access");
        _;
    }

    constructor() {}

    function init() public {
        //add banks
        addBank("ABC", 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, "111");
        addBank("DEF", 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, "222");
        addBank("GHI", 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, "333");
        addBank("JKL", 0x617F2E2fD72FD9D5503197092aC168c91465E7f2, "444");
        addBank("MNO", 0x17F6AD8Ef982297579C203069C1DbfFE4348c372, "555");
    }

    // BANK INTERFACE

    /** Add new customer */
    function addCustomer(string memory customerName, string memory data) public returns(bool) {
        /** check if customer is exist or not - allow adding new customer if customer is not present*/
        require(customers[customerName].validatorBank == address(0), "Customer is already present!");
        customers[customerName].username = customerName;
        customers[customerName].data = data;
        customers[customerName].validatorBank = msg.sender;
        customers[customerName].kycStatus = false;
        customers[customerName].upvotes = 0;
        customers[customerName].downvotes = 0;
        return true;  
    }

    /** Modify customer's data of existing customer */
    function modifyCustomer(string memory customerName, string memory data) public returns(bool) {
        /** check if customer is exist or not */
        require(customers[customerName].validatorBank != address(0), "Customer is not present in the database");
        customers[customerName].data = data;
        return true;
    }

    /** Get customer details */
    function getCustomer(string memory customerName) public view returns(string memory, string memory, address){
        /** check if customer is exist or not */
        require(customers[customerName].validatorBank != address(0), "Customer is not present in the database");
        return (customers[customerName].username, customers[customerName].data, customers[customerName].validatorBank);
    }

    /** Add new KYC request entry from customer */
    //TODO: (additional feature) check if KYC request is already present and not verified
    //TODO: (additional feature) remove KYC request once it's verified or disqualified
    function addKycRequest(string memory customerName, string memory dataHash) public{
        /** customer should be added first before adding KYC request for the customer verification*/
        require(customers[customerName].validatorBank != address(0), "Customer is not present in the database");
        /** complaints reported against calling bank should be less than or equal to 1/3rd of
        *total number of banks**/
        require(banks[msg.sender].complaintsReported <= (totalBanks/3), "Not allowed");

        /**create a KYC request */
        requests[customerName].username = customerName;
        requests[customerName].bankAddress = msg.sender;
        requests[customerName].customerData = dataHash;
    }

    /** Remove submitted KYC request */
    function removeKycRequest(string memory customerName) public {
        /** complaints reported against calling bank should be less than or equal to 1/3rd of
        *total number of banks**/
        require(banks[msg.sender].complaintsReported <= (totalBanks/3), "Not allowed");
        /** check KYC request exist or not*/
        require(requests[customerName].bankAddress != address(0), "Couldn't find KYC request for this customer");

        /** Delete KYC request */
        delete requests[customerName];
    }

    function upvoteCustomer(string memory name) public {
        /** customer should be added first before adding KYC request for the customer verification*/
        require(customers[name].validatorBank != address(0), "Customer is not present in the database");
        /** one bank can vote only once for any customer */
        require(votes[name][msg.sender] != 1, "You have already casted your vote");

        /** decrement downvotes if calling bank had voted down previously */
        if(votes[name][msg.sender] == 2){
            customers[name].downvotes -= 1;
        }

        /** upvote */
        customers[name].upvotes += 1;
        votes[name][msg.sender] = 1;
        this.modifyKycStatus(name);
    }

    function downvoteCustomer(string memory name) public {
        require(customers[name].validatorBank != address(0), "Customer is not present in the database");
        require(votes[name][msg.sender] != 2, "You have already casted your vote");

        if(votes[name][msg.sender] == 1){
            customers[name].upvotes -= 1;
        }

        customers[name].downvotes += 1;
        votes[name][msg.sender] = 2;
        this.modifyKycStatus(name);
    }

    function modifyKycStatus(string memory name) external {
        if(customers[name].upvotes > customers[name].downvotes
         && customers[name].downvotes <= totalBanks / 3) {
            customers[name].kycStatus = true;
        } else {
            customers[name].kycStatus = false;
        }
    }

    function getBankComplaints(address bankAddress) public view returns(uint256) {
        require(banks[bankAddress].ethAddress == bankAddress, "Bank is not present");
        return banks[bankAddress].complaintsReported;
    }

    function viewBankDetails(address bankAddress) public view returns(Bank memory) {
        require(banks[bankAddress].ethAddress == bankAddress, "Bank is not present");
        return banks[bankAddress];
    }

    function reportBank(address bankAddress) public {
        require(banks[bankAddress].ethAddress == bankAddress, "Bank is not present");
        banks[bankAddress].complaintsReported += 1;
    }


    //ADMIN INTERFACE

    function addBank(string memory bankName, address bankAddress, string memory regNumber) public onlyAdmin {
        require(banks[bankAddress].ethAddress != bankAddress, "Bank is already present");
        banks[bankAddress].name = bankName;
        banks[bankAddress].ethAddress = bankAddress;
        banks[bankAddress].regNumber = regNumber;
        banks[bankAddress].complaintsReported = 0;
        banks[bankAddress].allowedToVote = true;

        totalBanks += 1;
    }

    function removeBank(address bankAddress) public onlyAdmin {
        require(banks[bankAddress].ethAddress == bankAddress, "Bank is not present");
        delete banks[bankAddress];

        totalBanks -= 1;
    }

    function modifyBankAccessToVote(address bankAddress, bool allowed) public onlyAdmin {
        require(banks[bankAddress].ethAddress == bankAddress, "Bank is not present");
        banks[bankAddress].allowedToVote = allowed;
    }

}