// SPDX-License-Identifier: GPL-3.0
pragma experimental ABIEncoderV2;
pragma solidity >=0.4.25 <0.9.0;


import "./Customers.sol";
import "./Banks.sol";


contract KYC2 is Customers, Banks {
    address admin;
    address[] internal userList;

    mapping(address => Types.User) internal users;
    mapping(string => Types.KycRequest) internal kycRequests;
    mapping(address => address[]) internal bankCustomers; // All customers associated to a Bank
    mapping(address => address[]) internal customerbanks; // All banks associated to a Customer


    constructor(string memory name_, string memory email_) {
        admin = msg.sender;
        Types.User memory usr_ = Types.User({
            name: name_,
            email: email_,
            id_: admin,
            role: Types.Role.Admin,
            status: Types.BankStatus.Active
        });
        users[admin] = usr_;
        userList.push(admin);
    }

    // Modifiers

    modifier isAdmin() {
        require(msg.sender == admin, "Only admin is allowed");
        _;
    }

    function kycRequestExists(string memory reqId_)
        internal
        view
        returns (bool)
    {
        require(!Helpers.compareStrings(reqId_, ""), "Request Id empty");
        return Helpers.compareStrings(kycRequests[reqId_].id_, reqId_);
    }

    function getKYCRequests(uint256 pageNumber, bool isForBank)
        internal
        view
        returns (uint256 totalPages, Types.KycRequest[] memory)
    {
        require(pageNumber > 0, " > zero");
        (
            uint256 pages,
            uint256 pageLength_,
            uint256 startIndex_,
            uint256 endIndex_
        ) = Helpers.getIndexes(
                pageNumber,
                isForBank
                    ? bankCustomers[msg.sender]
                    : customerbanks[msg.sender]
            );
        Types.KycRequest[] memory list_ = new Types.KycRequest[](pageLength_);
        for (uint256 i = startIndex_; i < endIndex_; i++)
            list_[i] = isForBank
                ? kycRequests[
                    Helpers.append(msg.sender, bankCustomers[msg.sender][i])
                ]
                : kycRequests[
                    Helpers.append(customerbanks[msg.sender][i], msg.sender)
                ];
        return (pages, list_);
    }

    // Events

    event KycRequestAdded(string reqId, string bankName, string customerName);
    event KycReRequested(string reqId, string bankName, string customerName);
    event KycStatusChanged(
        string reqId,
        address customerId,
        address bankId,
        Types.KycStatus status
    );
    event DataHashPermissionChanged(
        string reqId,
        address customerId,
        address bankId,
        Types.DataHashStatus status
    );


    function activateDeactivateBank(address id_, bool makeActive_)
        public
        isAdmin
    {
        // Updating in common list
        users[id_].status = activatedeactivatebank(id_, makeActive_);
    }


    function searchCustomers(address id_)
        public
        view
        isValidCustomer(id_)
        isValidBank(msg.sender)
        returns (
            bool,
            Types.Customer memory,
            Types.KycRequest memory
        )
    {
        bool found_;
        Types.Customer memory customer_;
        Types.KycRequest memory request_;
        (found_, customer_) = searchcustomers(id_, bankCustomers[msg.sender]);
        if (found_) request_ = kycRequests[Helpers.append(msg.sender, id_)];
        return (found_, customer_, request_);
    }

    function getBankRequests(uint256 pageNumber)
        public
        view
        isValidCustomer(msg.sender)
        returns (uint256 totalPages, Types.KycRequest[] memory)
    {
        return getKYCRequests(pageNumber, false);
    }



    function updateProfile(
        string memory name_,
        string memory email_,
        uint256 mobile_
    ) public isValidCustomer(msg.sender) {
        updateprofile(name_, email_, mobile_);
        users[msg.sender].name = name_;
        users[msg.sender].email = email_;
    }

    function whoAmI() public view returns (Types.User memory) {
        require(msg.sender != address(0), "Sender Id Empty");
        require(users[msg.sender].id_ != address(0), "User Id Empty");
        return users[msg.sender];
    }
function updateDatahash(string memory hash_, uint256 currentTime_)
        public
        isValidCustomer(msg.sender)
    {
        updatedatahash(hash_, currentTime_);
        address[] memory banksList_ = customerbanks[msg.sender];
        for (uint256 i = 0; i < banksList_.length; i++) {
            string memory reqId_ = Helpers.append(banksList_[i], msg.sender);
            if (kycRequestExists(reqId_)) {
                kycRequests[reqId_].dataHash = hash_;
                kycRequests[reqId_].updatedOn = currentTime_;
                kycRequests[reqId_].status = Types.KycStatus.Pending;
                kycRequests[reqId_].additionalNotes = "Updated all my docs";
            }
        }
    }
    function removerDatahashPermission(address bankId_, string memory notes_)
        public
        isValidCustomer(msg.sender)
    {
        string memory reqId_ = Helpers.append(bankId_, msg.sender);
        require(kycRequestExists(reqId_), "Permission not found");
        kycRequests[reqId_].dataRequest = Types.DataHashStatus.Rejected;
        kycRequests[reqId_].additionalNotes = notes_;
        emit DataHashPermissionChanged(
            reqId_,
            msg.sender,
            bankId_,
            Types.DataHashStatus.Rejected
        );
    }

    function getCustomerDetails(address id_)
        public
        view
        isValidCustomer(id_)
        returns (Types.Customer memory)
    {
        return getcustomerdetails(id_);
    }

}