
---

# PropertyRegistry Smart Contract

This Solidity smart contract implements a decentralized system for **recording**, **validating**, and **governing** property information on the Ethereum blockchain. Each property record consists of attributes that detail aspects of the property, such as location, size, and value, stored publicly. The contract also includes a governance and voting mechanism for approving proposed modifications to these records. This system is backed by an ERC20 token model, where token holders have governance rights based on their token balances.

## Features

- **Record Attributes**: Store immutable attributes for a property, represented as `bytes32` data types.
- **Judge Validation**: Judges can validate individual attributes, providing a system of external verification.
- **Governance & Voting**: Record owners can propose changes, and the voting weight is based on token ownership.
- **ERC20 Token Integration**: Tokens represent governance power and can be transferred freely between owners.

## Contract Structure

The smart contract consists of multiple key functions to enable attribute recording, voting, judge validation, and token transfers.

### Key Functions

#### Constructor

```solidity
constructor(address[] memory initialOwners, uint[] memory initialTokensPerOwner, uint _minApprovalTokens)
```

- Initializes the contract with a list of owners, their respective token balances, and the minimum number of tokens required for proposal approval.

#### Token Transfer

```solidity
function transferOwnershipTokens(address to, uint256 amount) public
```

- Transfers tokens from one owner to another, leveraging the ERC20 standard.

#### Proposals

Owners can create proposals for:
1. **Adding a New Attribute**:
   ```solidity
   function proposeNewAttribute(bytes32 description) public onlyOwner returns (uint);
   ```

2. **Modifying an Existing Attribute**:
   ```solidity
   function proposeModifyAttribute(uint attributeId, bytes32 newDescription) public onlyOwner returns (uint);
   ```

3. **Registering a New Judge**:
   ```solidity
   function proposeRegisterJudge(uint attributeId, address judge) public onlyOwner returns (uint);
   ```

4. **Setting New Minimum Tokens for Approval**:
   ```solidity
   function proposeNewVotesForApproval(uint newAmount) public onlyOwner returns (uint);
   ```

5. **Minting New Tokens**:
   ```solidity
   function proposeMindNewTokens(address[] memory targetAddresses, uint[] memory amountOfTokens) public onlyOwner returns (uint);
   ```

#### Judge Validation

```solidity
function registerValidationByJudge(uint idAttribute) public onlyValidAttributes(idAttribute) onlyJudgesAllowed(idAttribute)
```

- Allows an approved judge to validate a specific attribute.

#### Voting & Approval

- **Vote on Proposal**:
   ```solidity
   function voteOnPropose(uint proposalId) public onlyOwner
   ```
   - Allows token holders to cast votes on active proposals.

- **Approve Proposal**:
   ```solidity
   function approveProposal(uint proposalId) public
   ```
   - Approves a proposal if it has the required votes.

#### Data Retrieval

1. **Get Proposal Status**:
   ```solidity
   function getProposalStatus(uint proposalId) public view returns (uint _votesInFavor, bool[] memory _votingStatus)
   ```
   - Retrieves voting information for a proposal.

2. **Get Validations for an Attribute**:
   ```solidity
   function getValidations(uint attributeId) public view returns (address[] memory _judgesWhoValidated)
   ```
   - Retrieves the list of judges who validated an attribute.

3. **Get Attribute Description**:
   ```solidity
   function getAttributeDescription(uint attributeId) public view returns (bytes32 _description)
   ```
   - Returns the description of a specified attribute.

## Usage Guide

1. **Deploy the Contract**:
   - Deploy with an initial set of owners and their token balances, along with the minimum tokens required for proposal approval.

2. **Propose New Attributes or Changes**:
   - Use the proposal functions to add new attributes or modify existing ones. Each proposal requires voting for approval.

3. **Vote and Approve Proposals**:
   - Owners vote on proposals, with their voting power proportional to their token balances.

4. **Judge Validation**:
   - Assign judges to attributes for external verification and use `registerValidationByJudge` to confirm validations.

5. **Transfer Tokens**:
   - Use `transferOwnershipTokens` to transfer governance tokens between owners.

## Example Workflow

1. **Create New Attribute Proposal**:
   ```solidity
   uint proposalId = contractInstance.proposeNewAttribute("Location: Downtown");
   ```

2. **Vote on Proposal**:
   ```solidity
   contractInstance.voteOnPropose(proposalId);
   ```

3. **Approve Proposal**:
   ```solidity
   contractInstance.approveProposal(proposalId);
   ```

4. **Register Validation by Judge**:
   ```solidity
   contractInstance.registerValidationByJudge(attributeId);
   ```

## Dependencies

- **Solidity** 0.8.x or higher
- **OpenZeppelin ERC20** Library for token functionality

---

## Security Considerations

- Ensure each address has the appropriate permissions to avoid unauthorized access.
- Only trusted addresses should be registered as judges to ensure the integrity of attribute validation.

---

## License

This project is licensed under the MIT License.# PropertyRegistrySmartContract
