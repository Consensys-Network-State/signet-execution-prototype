
## Description

Prototype implementation for an end-to-end execution engine for the [Signet Agreement Data Standard](https://github.com/Consensys-Network-State/signet-data-standard).

## Overview

<img width="1031" alt="image" src="https://github.com/user-attachments/assets/e770a049-9818-42de-9958-61b7a86e91e5" />

[Source](https://www.figma.com/board/ZsUIUaHzEv1G3PpNlS9hyM/Agreements-Backend?node-id=0-1&p=f&t=ZkkXIpOacDahsPc6-0)

## Agreement Process Flow
1. Agreement Creation
Creator user (Legal Team) initializes the agreement by signing a VC (Verifiable Credential) containing the agreement template and Party A's Ethereum address
The signed agreement is sent to the Agreements API via POST /agreement
2. Agreement Initialization
Backend API asks AO to create a new Agreement Actor
The init action is called on the new actor, which verifies the VC and initializes the DFSM (Deterministic Finite State Machine)
AO Testnet spawns an AO Agreement Actor
3. Party A Confirmation
Party A sends a VC signed with their Ethereum address
The VC contains their data to confirm identity and provides Party B's address
This is sent to the API via POST /agreement/:id/input
4. Party B Confirmation
Party B sends their data to confirm their identity
This is processed through the same input endpoint
5. Ongoing State Transitions
Both parties continue going back and forth supplying inputs for further transitions
The Agreement Actor processes these inputs and updates the state
Each input is passed to the Agreement Actor for verification and state transitions in the DFSM
6. State Monitoring
At any time, anyone can view an agreement's state via GET /agreement/:id/state
The state includes all pending actions and exactly which parties are accountable for each action
7. Completion
The process continues until the agreement reaches its complete state

## Example Agreement

<img width="1328" alt="image" src="https://github.com/user-attachments/assets/1f2a88c1-ed2d-4e8d-8ba0-70260d2d0234" />

[Source](https://www.figma.com/board/ZsUIUaHzEv1G3PpNlS9hyM/Agreements-Backend?node-id=0-1&p=f&t=ZkkXIpOacDahsPc6-0)

## Initial State
- **Input**: VC - Template + Initial Agreement with Party A Identity Parameter
- **DFSM State**: The state machine initializes with "Waiting for Party A Data" as the active state (highlighted in green)
- **Variables Needed**: Party A Identity, Party B Identity, Party B Name
- **Parameters Set**: Party A Identity Value (purple box)

## After Party A Data Input
- **Input**: VC - Party A Data with Variable Values (Party A Name, Party B Identity)
- **DFSM State**: Transitions to "Waiting for Party B Data" as the active state (highlighted in green)
- **Previous State**: "Waiting for Party A Data" becomes inactive
- **Variables Updated**: Party A Name and Party B Identity are now populated

## After Party B Data Input
- **Input**: VC - Party B Data with Variable Values (Party B Name)
- **DFSM State**: Transitions to "Party A Review" as the active state (highlighted in green)
- **Previous State**: "Waiting for Party B Data" becomes inactive
- **Variables Updated**: Party B Name is now populated

## Final State - Two Possible Outcomes
- **Decision Point**: Party A Review Process (diamond shape) leads to two possible inputs

### Acceptance Path
- **Input**: VC - Party A Review with Variable Value "ACCEPTED"
- **DFSM State**: Transitions to "Accepted" as the final state (highlighted in green in the Accepted column)
- **Previous State**: "Party A Review" becomes inactive

### Rejection Path
- **Input**: VC - Party A Review with Variable Value "REJECTED"
- **DFSM State**: Transitions to "Rejected" as the final state (highlighted in red in the Rejected column)
- **Previous State**: "Party A Review" becomes inactive

