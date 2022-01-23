// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.9;


contract KYC {

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

    mapping(string => Customer) public customers;

    mapping(address => Bank) public banks;

    mapping(string => KycRequest) public requests;

    constructor() {}


    // BANK INTERFACE

    function addCustomer(string memory name, string memory data) public returns(bool) {
        require(customers[name].validatorBank == address(0), "Customer is lready present!");

        customers[name].username = name;
        customers[name].data = data;
        customers[name].validatorBank = msg.sender;
        return true;  
    }

    function modifyCustomer(string memory name, string memory data) public returns(bool) {
        require(customers[name].validatorBank != address(0), "Customer is not present in the database");

        customers[name].data = data;
        return true;
    }

    function getCustomer(string memory name) public view returns(string memory, string memory, address){
        require(customers[name].validatorBank != address(0), "Customer is not present in the database");

        return (customers[name].username, customers[name].data, customers[name].validatorBank);
    }

    function addKycRequest(string memory customerName, string memory dataHash) public{
        requests[customerName].username = customerName;
        requests[customerName].bankAddress = msg.sender;
        requests[customerName].customerData = dataHash;
    }

    function removeKycRequest(string memory customerName) public {
        delete requests[customerName];
    }

    function upvoteCustomer(string memory name) public {
        customers[name].upvotes += 1;
    }

    function downvoteCustomer(string memory name) public {
        customers[name].downvotes += 1;
    }

    function getBankComplaints(address bankAddress) public view returns(uint256) {
        return banks[bankAddress].complaintsReported;
    }

    function viewBankDetails(address bankAddress) public view returns(Bank memory) {
        return banks[bankAddress];
    }

    function reportBank(address bankAddress) public {
        banks[bankAddress].complaintsReported += 1;
        //TODO: toggle isAllow boolean
    }


    //ADMIN INTERFACE

    function addBank(string memory bankName, address bankAddress, string memory regNumber) public {

        banks[bankAddress].name = bankName;
        banks[bankAddress].ethAddress = bankAddress;
        banks[bankAddress].regNumber = regNumber;
        banks[bankAddress].complaintsReported = 0;
        banks[bankAddress].allowedToVote = true;
    }

    function removeBank(address bankAddress) public {
        delete banks[bankAddress];
    }

    function modifyBankAccessToVote(address bankAddress, bool allowed) public {
        banks[bankAddress].allowedToVote = allowed;
    }

}