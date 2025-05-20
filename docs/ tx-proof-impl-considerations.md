# Transaction Proof Implementation Considerations

This document outlines our initial approach to implementing transaction proof verification. Our first implementation requires the `txHash` as input and mandates the inclusion of all necessary components to verify both the raw transaction's Merkle proof and the transaction receipt's Merkle proof. By standardizing these inputs, we ensure that any party can independently confirm that a transaction was included in a specific block and that its outcome matches the provided receipt. The following sections detail the required proof components, core fields, and important security considerations for robust and reliable transaction proof verification across different execution environments.

## Core Proof Components

Every transaction proof must include the following five core components to ensure proper verification:

1. **Transaction Receipt** - Confirms the transaction was processed and its outcome
2. **Raw Transaction** - The original transaction data as submitted to the network
3. **Block Header** - Header of the block containing the transaction
4. **Transaction Receipt Merkle Proof** - Proof of receipt inclusion in the block
5. **Transaction Merkle Proof** - Proof of transaction inclusion in the block


## Implementation Specific Core Fields

To simplify processing of the core proof components in our prototype implementation, we also preprocess and extract certain values (such as RLP-encoded transaction and receipt values, and transaction indices) ahead of time. This preprocessing step makes validation logic within the prototype more straightforward and reduces the need for complex parsing or encoding operations during proof verification.

Each of the fields below is either directly present in, or can be derived from, the five core proof components listed above. For example:
- `TxHash`, `TxRaw`, and `TxEncodedValue` are obtained from the **Raw Transaction**.
- `TxReceipt` and `ReceiptEncodedValue` are found in the **Transaction Receipt**.
- `TxRoot`, `ReceiptRoot`, and `TxIndex` are present in the **Block Header**.
- `TxProof` and `ReceiptProof` are the **Transaction Merkle Proof** and **Transaction Receipt Merkle Proof**, respectively. These are constructed using the other core components as well as the other transactions that are included within the same block.

By requiring these fields, we ensure that all necessary data for independent verification is included, and that each field can be traced back to a specific component of the proof.

| Field | Type | Description | Required |
| --- | --- | --- | --- |
| `TxHash` | `string` | Transaction hash/ID | ✅ |
| `TxRoot` | `string` | Transactions root from block header | ✅ |
| `TxIndex` | `string` | Transaction index in the block | ✅ |
| `TxRaw` | `object` | The complete raw transaction data | ✅ |
| `TxReceipt` | `object` | Complete transaction receipt | ✅ |
| `TxProof` | `array` | Merkle proof nodes for transaction inclusion | ✅ |
| `TxEncodedValue` | `array` | RLP-encoded transaction value | ✅ |
| `ReceiptRoot` | `string` | Receipts root from block header | ✅ |
| `ReceiptProof` | `array` | Merkle proof nodes for receipt inclusion | ✅ |
| `ReceiptEncodedValue` | `array` | RLP-encoded receipt value | ✅ |

## Risks

### Contract Deployment Proof Definitions

This section addresses the challenges of verifying that a particular contract was deployed with specific parameters. This verification process is complex, especially when considering the diverse technical backgrounds of agreement authors and their varying levels of contract knowledge:


1. **Domain Knowledge Requirements**
  - When contracts follow proxy or factory patterns, agreement authors must identify the specific factory contract address and deployment method. This information is often abstracted away by deployment tools or SDKs, making it difficult to access.
  - Note that with proper factory contract information, we can verify deployments using the contract call proof mechanism described earlier in this document.


2. **Bytecode Verification Challenges**
  - For custom contracts, proper validation requires the compiled bytecode as an input to the proof definition.
  - This would necessitate knowledge of how to compile the contract with the correct compiler version and parameters for the target chain, creating a significant technical barrier for many users.


**Mitigation Strategy**:
- **Phase 1**: Focus on supporting widely-used contracts that typically employ proxy or factory patterns. These represent the majority of contracts our users will interact with and can be verified through contract call proofs.
- **Phase 2**: For custom contracts, we will initially provide a simplified approach where transaction receipts serve as inputs for state transitions. While not providing means for full verification within the execution environment, this data can still be independently verified if needed.


## Security Considerations

### Verification of the Canonical Chain

Transaction proofs alone cannot guarantee that a block is part of the canonical blockchain without external verification. This creates a potential security gap where an attacker could:


1. Fork a public blockchain (e.g., Ethereum mainnet)
2. Create valid transactions on this fork
3. Generate legitimate-looking proofs for these transactions
4. Submit these proofs to an agreement


These proofs would technically validate correctly since they contain valid cryptographic signatures and merkle proofs, but they represent transactions that never occurred on the canonical chain that the agreement intends to reference.


**Mitigation**: Implementations should verify block hashes against trusted sources (like multiple independent RPC providers) to confirm the block exists on the canonical chain. Critical agreements may require additional verification through multiple independent sources.


### Chain Reorganizations


Even when a transaction is included in the canonical chain, newer blocks have a chance to be removed during chain reorganizations ("reorgs"). The probability of a block being removed decreases exponentially with each subsequent block built on top of it.


For proper security, agreements should consider the number of confirmations (blocks built on top of the transaction's block) based on the value and criticality of the transaction:


| Confirmations | Security Level | Waiting Period | Suitable For |
|---------------|----------------|----------------|--------------|
| 1-2 | Minimal | ~30 seconds | Low-value transactions |
| 6 | Standard | ~1-2 minutes | Regular transactions |
| 12+ | High | ~3-5 minutes | High-value transactions |
| 30+ | Maximum | ~7-10 minutes | Critical or extremely high-value transactions |


**Mitigation**: Agreement implementations should specify minimum confirmation requirements based on the security needs of the specific use case. For high-value agreements, waiting for more confirmations provides greater security against chain reorganizations.


### RPC Trust


Direct verification of transaction proofs often relies on RPC endpoints to confirm canonical chain inclusion. This introduces trust assumptions about the RPC providers:


1. The RPC provider could return incorrect data
2. A compromised or malicious RPC provider could falsely confirm invalid transactions
3. If using a single RPC endpoint, its unavailability creates a single point of failure


**Mitigation**: Critical implementations should:
- Use multiple independent RPC providers and compare results
- In the case of AO as the execution environment, we would need some kind of trusted oracle to provide chain state


## Implementations


This section outlines how transaction proofs can be implemented across different execution environments.


### Arweave/AO Implementation


Arweave/AO provides a unique execution environment for transaction proof verification with distinct advantages and challenges.


Using the standardized inputs defined in this proposal, we can write logic in AO processes that can verify without network calls that:
1. A transaction was legitimately included in a specific block
2. The transaction performed exactly what it claims (e.g., called a specific contract method with particular parameters or transferred a precise amount of native tokens)
3. All verification data is permanently stored on Arweave's underlying storage layer


This creates an immutable, decentralized audit trail that can be independently verified by any party at any time without requiring trust in centralized verification services.


The primary challenge with AO implementation stems from its limited ability to make external network calls. As outlined in the security considerations section, complete verification requires confirming that a block exists on the canonical chain. Several potential approaches to address this limitation include:


1. **Trusted Chain Data Providers** - Establish a curated registry of verified data providers that consistently deliver accurate canonical chain information. These providers would undergo regular audits and implement multiple redundancy checks to ensure data integrity. In our case we could have some kind of backend service for APOC that we trust is providing real data from the canonical chains. This would also be a simple first iteration for an implementation of the protocol.


2. **AO Oracle Integration** - Leverage AO's trusted oracle framework to securely access real-time chain state data. More research is required into the this strategy


3. **Zero-Knowledge Bridge Implementation** - Explore the ao-zk-bridge solution to create a dedicated actor that maintains synchronized state with target blockchains. This bridge would use zero-knowledge proofs to cryptographically verify chain state without requiring trust in individual data providers.


