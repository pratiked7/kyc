// SPDX-License-Identifier: MIT
pragma solidity >=0.5.9;
pragma experimental ABIEncoderV2;

contract KYC {

    /** only one admin to monitor, add, remove, modify banks */
    address adminAddress;

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

    /** struct : Bank
        name (string) - name of the bank
        ethAddress (address) - unique account address of the bank
        regNumber (string) - registration number of the bank
        complaintReported (uint) - number of complaints reported against the bank
        kycCount (uin) - number of KYC submitted by the bank
        allowedToVote (bool) -  admin can disable bank's voting power in customer verification
     */
    struct Bank {
        string name;
        address ethAddress;
        string regNumber;
        uint256 complaintsReported;
        uint256 kycCount;
        bool allowedToVote;
    }

    /** struct : KycRequest
        username (string) - unique name of the customer
        bankAddress (address) - address of the bank that submitted the request
        customerData (string) - data submitted by customer for verification
     */
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

    //modifier: check if bank is valid bank
    modifier validBank {
        require(banks[msg.sender].complaintsReported <= (totalBanks / 2), "Not a valid bank");
        _;
    }

    modifier allowedVoting {
        require(banks[msg.sender].allowedToVote, "Not allowed to vote");
        _;
    }

    constructor() public {
        adminAddress = msg.sender;
    }

    /** Helper method to add dummy banks */
    function init() public {
        //add banks
        addBank("ABC", 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, "111");
        addBank("DEF", 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, "222");
        addBank("GHI", 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, "333");
        addBank("JKL", 0x617F2E2fD72FD9D5503197092aC168c91465E7f2, "444");
        addBank("MNO", 0x17F6AD8Ef982297579C203069C1DbfFE4348c372, "555");
    }



    //ADMIN INTERFACE

    /** Add new bank
        bankName: Name of the bank
        bankAddress: unique account address of the bank
        regNumber: registration number of the bank

        onlyAdmin - only admin can add a new bank
     */
    function addBank(string memory bankName, address bankAddress, string memory regNumber) public onlyAdmin {
        require(banks[bankAddress].ethAddress != bankAddress, "Bank is already present");
        banks[bankAddress].name = bankName;
        banks[bankAddress].ethAddress = bankAddress;
        banks[bankAddress].regNumber = regNumber;
        banks[bankAddress].complaintsReported = 0;
        banks[bankAddress].allowedToVote = true;

        totalBanks += 1;
    }

    /** Remove a bank
        bankAddress: unique account address of the bank

        onlyAdmin - only admin can remove a bank
     */
    function removeBank(address bankAddress) public onlyAdmin {
        require(banks[bankAddress].ethAddress == bankAddress, "Bank is not present");
        delete banks[bankAddress];

        totalBanks -= 1;
    }

    /** Modify Acceess to vote for a bank 
        bankAddress: unique account address of a bank
        allowed: allowed to vote or not

        onlyAdmin - only admin can change the access to vote for a bank
    */
    function modifyBankAccessToVote(address bankAddress, bool allowed) public onlyAdmin {
        require(banks[bankAddress].ethAddress == bankAddress, "Bank is not present");
        banks[bankAddress].allowedToVote = allowed;
    }


    // BANK INTERFACE

    /** Add new customer 
        customername: name of the customer
        data: data of the customer
    */
    function addCustomer(string memory customerName, string memory data) public validBank {
        /** check if customer is exist or not - allow adding new customer if customer is not present*/
        require(customers[customerName].validatorBank == address(0), "Customer is already present!");

        customers[customerName].username = customerName;
        customers[customerName].data = data;
        customers[customerName].validatorBank = msg.sender;
        customers[customerName].kycStatus = false;
        customers[customerName].upvotes = 0;
        customers[customerName].downvotes = 0;
    }

    /** Modify customer's data of existing customer
        customerName: name of the customer whose data is need to be modified
        data: new data of the customer
     */
    function modifyCustomer(string memory customerName, string memory data) public validBank {
        /** check if customer is exist or not */
        require(customers[customerName].validatorBank != address(0), "Customer is not present in the database");
        customers[customerName].data = data;
    }

    /** Get customer details
        customerName: name of the customer
     */
    function getCustomer(string memory customerName) public view returns(string memory, string memory, address){
        /** check if customer is exist or not */
        require(customers[customerName].validatorBank != address(0), "Customer is not present in the database");
        return (customers[customerName].username, customers[customerName].data, customers[customerName].validatorBank);
    }

    /** Add new KYC request entry from customer */
    //TODO: (additional feature) check if KYC request is already present and not verified
    //TODO: (additional feature) remove KYC request once it's verified or disqualified
    function addKycRequest(string memory customerName, string memory dataHash) public {
        /** customer should be added first before adding KYC request for the customer verification*/
        require(customers[customerName].validatorBank != address(0), "Customer is not present in the database");
        /** complaints reported against calling bank should be less than or equal to 1/3rd of
        *total number of banks**/
        require(banks[msg.sender].complaintsReported <= (totalBanks/3), "Not allowed because of complaints");

        /**create a KYC request */
        requests[customerName].username = customerName;
        requests[customerName].bankAddress = msg.sender;
        requests[customerName].customerData = dataHash;
    }

    /** Remove submitted KYC request
        customerName: name of the customer
     */
    function removeKycRequest(string memory customerName) public {
        /** complaints reported against calling bank should be less than or equal to 1/3rd of
        *total number of banks**/
        require(banks[msg.sender].complaintsReported <= (totalBanks/3), "Not allowed because of complaints");
        /** check KYC request exist or not*/
        require(requests[customerName].bankAddress != address(0), "Couldn't find KYC request for this customer");

        /** Delete KYC request */
        delete requests[customerName];

        /** Reset votes and KYC status */
        customers[customerName].kycStatus = false;
        customers[customerName].upvotes = 0;
        customers[customerName].downvotes = 0;
    }

    /** Upvote customer
        name: name of the customer
     */
    function upvoteCustomer(string memory name) public allowedVoting {
        /** customer should be added first before adding KYC request for the customer verification*/
        require(customers[name].validatorBank != address(0), "Customer is not present in the database");
        /** kyc request should be added for voting */
        require(requests[name].bankAddress != address(0), "KYC request not found");
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

    /** Downvote customer
        name: name of the customer
     */
    function downvoteCustomer(string memory name) public allowedVoting {
         /** customer should be added first before adding KYC request for the customer verification*/
        require(customers[name].validatorBank != address(0), "Customer is not present in the database");
        /** kyc request should be added for voting */
        require(requests[name].bankAddress != address(0), "KYC request not found");
        /** one bank can vote only once for any customer */
        require(votes[name][msg.sender] != 2, "You have already casted your vote");

        /** decrement upvotes if calling bank had voted up previously */
        if(votes[name][msg.sender] == 1){
            customers[name].upvotes -= 1;
        }

        /** Downvote */
        customers[name].downvotes += 1;
        votes[name][msg.sender] = 2;
        this.modifyKycStatus(name);
    }

    /** Modify KYC status
        name: customerName
     */
    function modifyKycStatus(string memory name) public {
        if(customers[name].upvotes > customers[name].downvotes
         && customers[name].downvotes <= totalBanks / 3) {
            customers[name].kycStatus = true;
        } else {
            customers[name].kycStatus = false;
        }
    }

    /** Get number of bank complaints against a bank
        bankAddress: unique account address of the bank
     */
    function getBankComplaints(address bankAddress) public view returns(uint256) {
        require(banks[bankAddress].ethAddress != address(0), "Bank is not present");
        return banks[bankAddress].complaintsReported;
    }

    /** Get Bank details
        bankAddress: unique account address of the bank
     */
    function viewBankDetails(address bankAddress) public view returns(Bank memory) {
        require(banks[bankAddress].ethAddress != address(0), "Bank is not present");
        return banks[bankAddress];
    }

    /** Report against a bank
        bankAddress: unique account address of the bank
     */
    function reportBank(address bankAddress) public validBank {
        require(banks[bankAddress].ethAddress != address(0), "Bank is not present");
        banks[bankAddress].complaintsReported += 1;

        /** If number of complaints is greater than half of the total number of banks
            block banks from voting
         */
        if(banks[bankAddress].complaintsReported > (totalBanks / 2)) {
            banks[bankAddress].allowedToVote = false;
        }
    }
}