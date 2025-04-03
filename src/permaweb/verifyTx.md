# Ethereum Transaction Verification System

This document explains the transaction verification system implemented across two files: `verifyTx.js` and `verifyTx.lua`. Together, these files create a system for verifying Ethereum transactions using Merkle Patricia Tries and storing the verification proofs on the Permaweb.

## Overview

The system consists of two main components:

1. **JavaScript Client (`verifyTx.js`)**: Generates transaction proofs from Ethereum nodes
2. **Lua Verification Actor (`verifyTx.lua`)**: Verifies transaction proofs in the AO environment

## JavaScript Client (`verifyTx.js`)

This component connects to Ethereum nodes to retrieve transaction data and generate cryptographic proofs.

### Key Functions:

#### `getTransactionProof(txHash)`
- Retrieves a transaction and its containing block from an Ethereum node
- Reconstructs the Merkle Patricia Trie containing all transactions in the block
- Generates a proof that the specific transaction exists in the trie
- Returns the transaction data, block data, and proof

#### `verifyTransactionProof(txHash, transactionIndex, block, proof, value)`
- Verifies a transaction proof locally
- Confirms that the transaction data can be derived from the block's transaction root using the provided proof

### How Transaction Values Are Stored:

The `verifiedValue` returned by `trie.verifyProof()` is the complete serialized transaction data stored as a leaf node in the Merkle Patricia Trie. This includes:

- For legacy transactions: RLP-encoded transaction data
- For EIP-2930 transactions: `0x01` + RLP-encoded transaction data
- For EIP-1559 transactions: `0x02` + RLP-encoded transaction data

## Lua Verification Actor (`verifyTx.lua`)

This component runs in the AO environment and independently verifies transaction proofs.

### Key Components:

#### RLP Implementation
- Custom RLP (Recursive Length Prefix) encoding and decoding functions
- Handles Ethereum's data serialization format

#### Merkle Patricia Trie Implementation
- `Trie` class with methods to navigate and verify proofs
- Node types: `BranchNode`, `ExtensionNode`, and `LeafNode`

#### `verifyProof(txHash, transactionIndex, transactionRoot, proof, value)`
- Takes transaction data and proof as input
- Reconstructs the partial Merkle Patricia Trie from the proof
- Verifies that the transaction exists at the specified index
- Confirms that the transaction data matches the expected value
- Essentially an implmentation of the verifyProof from the verifyTx.js file

## Verification Process

1. **Proof Generation**:
   - The JavaScript client retrieves the transaction and block data
   - It reconstructs the full transaction trie
   - It generates a proof showing the path from the root to the transaction

2. **Proof Storage**:
   - The proof is sent to the Permaweb via the AO message system
   - The data includes transaction hash, root, index, proof path, and transaction value

3. **Proof Verification**:
   - The Lua actor receives the proof data
   - It reconstructs a partial trie using only the nodes in the proof
   - It verifies that the transaction exists at the claimed position
   - It confirms the transaction data matches the provided value

## TODOs
- Look into creating the Merkle Proof for the transaction receipts
- Need to be able to confirm the block is on the canonical chain some how

This system enables trustless verification of Ethereum transactions without requiring access to a full Ethereum node, making it suitable for cross-chain applications and decentralized verification services.
