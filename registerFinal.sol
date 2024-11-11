// https://eips.ethereum.org/EIPS/eip-20
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

event OwnershipTransferred(address indexed from, address indexed to, uint256 amount);
event AttributeAdded(uint indexed attributeId, bytes32 description);
event AttributeModified(uint indexed attributeId, bytes32 newDescription);
event JudgeRegistered(uint indexed attributeId, address indexed judge);
event ApprovalTokensModified(uint newAmount);
event TokensMinted(address[] targetAddresses, uint[] amounts, uint newTotal);
event ValidationRegistered(uint indexed attributeId, address indexed judge);

contract Register is ERC20 {

    //#-----------------Register Governation Data--------------#
    uint public minApprovalTokens;
    uint public totalAmountOfTokens;

    //#-----------------Attributes data------------#
    uint public attributesCount;
    struct Attribute {
        bytes32 description;
        mapping(address => bool) validations;
    }

    mapping (uint => Attribute) public attributes;
    mapping (uint => bool) internal registeredAttributes;

    //#-----------------Validation data----------------#
    mapping(uint => address[]) public permittedJudges;// Maps an attribute ID to a list of permitted judges
    mapping(uint => address[]) public validations;//mapping of judges who validated an attribute

    //#-----------------Proposals data-------------#
    uint256 public proposalCount;

    enum ProposalType {
        NewAttribute,
        ModifyAttribute,
        RegisterJudge,
        NewVotesForApproval,
        MindNewTokens
    }

    struct Proposal{
        uint votesInFavor;
        uint idToSpecificDataProposal;
        ProposalType especificType;
        mapping(address => bool) votes;
    }

    struct ModifyAttributeProposal {
        uint referenceId;
        bytes32 newDescription;
    }

    struct RegisterJudgeProposal {
        uint attributeId;
        address judge;
    }

    struct MindNewTokensProposal{
        address[] targetAddresses;
        uint[] amountOfTokens;
    }

    mapping(uint => Proposal) internal proposals;
    mapping(uint => bool) internal validProposals;

    mapping(uint => bytes32) internal newAttributeProposals;
    mapping(uint => ModifyAttributeProposal) internal modifyAttributeProposals;
    mapping(uint => RegisterJudgeProposal) internal registerJudgeProposals;
    mapping(uint => uint) internal newVotesForAprrovalProposals;
    mapping(uint => MindNewTokensProposal) internal mindNewTokensProposals;

    mapping(ProposalType => function(uint) internal) internal proposalApprovers;

    // Constructor to initialize owners
    constructor(address[] memory initialOwners, uint[] memory initialTokensPerOwner, uint _minApprovalTokens) 
        ERC20("PropertyToken", "PTKN") {
        //verify correct data of owners and their tokens
        require(initialOwners.length == initialTokensPerOwner.length && initialOwners.length > 0, 
            "Only owner data and consistent tokens are allowed"
        );

        //check if future approvals are possible
        uint length = initialOwners.length;
        uint newAmount = 0;
        for(uint i = 0; i < length; ++i){
            newAmount += initialTokensPerOwner[i];
        }
        require(newAmount >= _minApprovalTokens,
            "Initial approval configuration is invalid"
        );

        //initialize registry data
        minApprovalTokens = _minApprovalTokens;
        proposalCount = 0;
        attributesCount = 0;
        totalAmountOfTokens = 0;
        
        //register the initial owners' tokens
        for (uint i = 0; i < initialOwners.length; i++) {
            address owner = initialOwners[i];
            uint256 tokens = initialTokensPerOwner[i];
            totalAmountOfTokens += tokens;
            _mint(owner, tokens);  // Mint tokens for each owner
        }

        // Map each ProposalType to the corresponding approval function
        proposalApprovers[ProposalType.NewAttribute] = approveNewAttributeProposal;
        proposalApprovers[ProposalType.ModifyAttribute] = approveModifyAttributeProposal;
        proposalApprovers[ProposalType.RegisterJudge] = approveRegisterJudgeProposal;
        proposalApprovers[ProposalType.NewVotesForApproval] = approveNewVotesForApprovalProposal;
        proposalApprovers[ProposalType.MindNewTokens] = approveMindNewTokensProposal;
    }

    //#--------------Modifier functions----------------------#
    modifier onlyOwner() {
        require(balanceOf(msg.sender) > 0, "Only owners can perform this action"); _;
    }

    modifier onlyJudgesAllowed(uint idAttribute) {
        bool isJudgePermitted = false;
        address[] memory judges = permittedJudges[idAttribute];
        for (uint i = 0; i < judges.length; i++) {
            if (judges[i] == msg.sender) {
                isJudgePermitted = true;
                break;
            }
        }
        require(isJudgePermitted, "Only judges of this attribute can validate it.");
        _;
    }

    modifier onlyValidAttributes(uint attributeId) {
        require(registeredAttributes[attributeId], "The referenced ID is not a valid attribute"); _;
    }

    modifier onlyValidProposals(uint proposalId) {
        require(validProposals[proposalId], "The referenced ID is not a valid proposal"); _;
    }

    modifier onlyNewVoters(uint proposalId){
        require(!proposals[proposalId].votes[msg.sender], "Already voted"); _;
    }

    modifier onlyQualifiedProposals(uint proposalId){
        require(proposals[proposalId].votesInFavor >= minApprovalTokens,
        "Not enough votes to approve"); _;
    }

    modifier onlyValidTokenQuantity(uint newAmountOfTokens) {
        require(newAmountOfTokens <= totalAmountOfTokens,
        "Invalid amount of tokens");_;
    }

    //#----------------Fundamental Modification Functions--------------------#
    function transferOwnershipTokens(address to, uint256 amount) public {
        transfer(to, amount);  // Standard ERC-20 transfer function
        emit OwnershipTransferred(msg.sender, to, amount);
    }

    function addNewAttribute(bytes32 description) private {
        uint newAttributeId = attributesCount++;
        attributes[newAttributeId].description = description;
        registeredAttributes[newAttributeId] = true;
        emit AttributeAdded(newAttributeId, description);
    }

    function modifyAttribute(uint attributeId, bytes32 newDescription) private {
        attributes[attributeId].description = newDescription;//update description

        //delete judges validations
        address[] storage judges = permittedJudges[attributeId];
        for (uint i = 0; i < judges.length; i++) {
            delete attributes[attributeId].validations[judges[i]];
        }
        delete validations[attributeId];
        emit AttributeModified(attributeId, newDescription);
    }

    function registerJudge(uint attributeId, address judge) private {
        permittedJudges[attributeId].push(judge);
        emit JudgeRegistered(attributeId, judge);
    }

    function modifyAmountOfVotesForApproval(uint newAmount) private {
        minApprovalTokens = newAmount;
        emit ApprovalTokensModified(newAmount);
    }

    function mindNewTokens(address[] memory targetAddresses, uint[] memory amountOfTokens) private {
        uint length = targetAddresses.length;
        uint newTotal = 0;
        for(uint i = 0; i < length; ++i){
            _mint(targetAddresses[i], amountOfTokens[i]);
            newTotal += amountOfTokens[i];
        }
        totalAmountOfTokens += newTotal;
        emit TokensMinted(targetAddresses, amountOfTokens, newTotal);
    }

    function registerValidationByJudge(uint idAttribute)
        public onlyValidAttributes(idAttribute) onlyJudgesAllowed(idAttribute){
        attributes[idAttribute].validations[msg.sender] = true;
        validations[idAttribute].push(msg.sender);
        emit ValidationRegistered(idAttribute, msg.sender);
    }

    //#--------------Proposals functions-------------------------#
    function addNewProposal(ProposalType typeOf) private returns (uint) {
        Proposal storage proposal = proposals[proposalCount];
        proposal.votesInFavor = 0;
        proposal.idToSpecificDataProposal = proposalCount;
        proposal.especificType = typeOf;
        validProposals[proposalCount] = true;
        return proposalCount++;
    }

    function proposeNewAttribute(bytes32 description)
        public onlyOwner returns (uint) {
        uint newProposalId = addNewProposal(ProposalType.NewAttribute);
        newAttributeProposals[newProposalId] = description;
        return newProposalId;
    }

    function proposeModifyAttribute(uint attributeId, bytes32 newDescription) 
        public onlyOwner onlyValidAttributes(attributeId) returns (uint) {
        uint newProposalId = addNewProposal(ProposalType.ModifyAttribute);
        ModifyAttributeProposal storage proposal = modifyAttributeProposals[newProposalId];
        proposal.referenceId = attributeId;
        proposal.newDescription = newDescription;
        return newProposalId;
    }

    function proposeRegisterJudge(uint attributeId, address judge) 
        public onlyOwner onlyValidAttributes(attributeId) returns (uint) {
        uint newProposalId = addNewProposal(ProposalType.RegisterJudge);
        RegisterJudgeProposal storage proposal = registerJudgeProposals[newProposalId];
        proposal.attributeId = attributeId;
        proposal.judge = judge;
        return newProposalId;
    }

    function proposeNewVotesForApproval(uint newAmount) 
        public onlyOwner onlyValidTokenQuantity(newAmount) returns (uint) {
        uint newProposalId = addNewProposal(ProposalType.NewVotesForApproval);
        newVotesForAprrovalProposals[newProposalId] = newAmount;
        return newProposalId;
    }

    function proposeMindNewTokens(address[] memory targetAddresses, uint[] memory amountOfTokens)
        public onlyOwner returns (uint){
        uint newProposalId = addNewProposal(ProposalType.MindNewTokens);
        MindNewTokensProposal storage proposal = mindNewTokensProposals[newProposalId];
        proposal.targetAddresses = targetAddresses;
        proposal.amountOfTokens = amountOfTokens;
        return newProposalId;
    }

    //#-------------------Voting functions----------------------------#
    // Function to vote on a new attribute proposal
    function voteOnPropose(uint proposalId)
        public onlyOwner onlyValidProposals(proposalId) onlyNewVoters(proposalId) {
        proposals[proposalId].votes[msg.sender] = true;
        uint256 weight = balanceOf(msg.sender);  // Fetch token balance as vote weight
        proposals[proposalId].votesInFavor += weight;
    }

    //---------------------Approve functions--------------------------#
    function approveNewAttributeProposal(uint proposalId) internal {
        addNewAttribute(newAttributeProposals[proposalId]);
        delete newAttributeProposals[proposalId];
    }

    function approveModifyAttributeProposal(uint proposalId) internal {
        ModifyAttributeProposal storage proposal = modifyAttributeProposals[proposalId];
        modifyAttribute(proposal.referenceId, proposal.newDescription);
        delete modifyAttributeProposals[proposalId];
    }

    function approveRegisterJudgeProposal(uint proposalId) internal {
        RegisterJudgeProposal storage proposal = registerJudgeProposals[proposalId];
        registerJudge(proposal.attributeId, proposal.judge);
        delete registerJudgeProposals[proposalId];
    }

    function approveNewVotesForApprovalProposal(uint proposalId) internal {
        modifyAmountOfVotesForApproval(newVotesForAprrovalProposals[proposalId]);
        delete newVotesForAprrovalProposals[proposalId];
    }

    function approveMindNewTokensProposal(uint proposalId) internal {
        MindNewTokensProposal storage proposal = mindNewTokensProposals[proposalId];
        mindNewTokens(proposal.targetAddresses, proposal.amountOfTokens);
        delete mindNewTokensProposals[proposalId];
    }
    
    function approveProposal(uint proposalId)
        public onlyValidProposals(proposalId) onlyQualifiedProposals(proposalId){
        ProposalType proposalType = proposals[proposalId].especificType;
        function(uint) internal approveFunction = proposalApprovers[proposalType];
        approveFunction(proposalId);
        validProposals[proposalId] = false; //invalidates the proposal after it has already been approved
    }

    //#-------------------view/get functions----------------------------#
    function getNewAttributeProposal(uint proposalId) 
        public view onlyValidProposals(proposalId) 
        returns (bytes32 _description) {
        return (newAttributeProposals[proposalId]);
    }

    function getModifyAttributeProposal(uint proposalId) 
        public view onlyValidProposals(proposalId) 
        returns (uint _referenceId, bytes32 _newDescription) {
        ModifyAttributeProposal storage proposal = modifyAttributeProposals[proposalId];
        return (proposal.referenceId, proposal.newDescription);
    }

    function getRegisterJudgesProposal(uint proposalId) 
        public view onlyValidProposals(proposalId) 
        returns (uint _attributeId, address _judge) {
        RegisterJudgeProposal storage proposal = registerJudgeProposals[proposalId];
        return (proposal.attributeId, proposal.judge);
    }
    
    function getProposalStatus(uint proposalId, address[] memory voters)
        public view onlyValidProposals(proposalId)
        returns (uint _votesInFavor, bool[] memory _votingStatus) {
        // Recovers the vote count in favor of the proposal
        _votesInFavor = proposals[proposalId].votesInFavor;
        
        // Creates an array to store each voter's voting status
        _votingStatus = new bool[](voters.length);
        
        // Checks the status of each voter and stores it in the _votingStatus array
        for (uint i = 0; i < voters.length; i++) {
            _votingStatus[i] = proposals[proposalId].votes[voters[i]];
        }
    }

    function getValidations(uint attributeId)
        public view onlyValidAttributes(attributeId)
        returns (address[] memory _judgesWhoValidated){
        return (validations[attributeId]);
    }

    function getAttributeDescription(uint attributeId)
        public view onlyValidAttributes(attributeId)
        returns (bytes32 _description){
        return (attributes[attributeId].description);
    }
}