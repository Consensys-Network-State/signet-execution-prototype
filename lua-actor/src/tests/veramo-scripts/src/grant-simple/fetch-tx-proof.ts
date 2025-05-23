import 'dotenv/config';
import { Trie } from "@ethereumjs/trie";
import { RLP } from "@ethereumjs/rlp";
import { createTx } from '@ethereumjs/tx';
import { Mainnet, createCustomCommon } from '@ethereumjs/common';
import { trustedSetup } from '@paulmillr/trusted-setups/fast-kzg.js';
import { KZG as microEthKZG } from 'micro-eth-signer/kzg.js'
import { ethers } from "ethers";

const INFURA_API_KEY = process.env.INFURA_PROJECT_ID;
const LOGGING_ENABLED = false;

/**
 * Encodes a transaction receipt according to Ethereum rules
 * @param {Object} receipt - The transaction receipt object
 * @returns {Buffer} - The RLP encoded receipt
 */
function encodeReceipt(receipt: any) {
    // Determine receipt type
    const type = typeof receipt.type === 'string' ? 
        parseInt(receipt.type.slice(2), 16) : 
        (receipt.type === undefined ? 0 : Number(receipt.type));
    
    // Convert status to the correct format
    // Status can be boolean, hex string, or number
    let status;
    if (receipt.status !== undefined) {
        if (typeof receipt.status === 'boolean') {
            status = receipt.status ? 1 : 0;
        } else if (typeof receipt.status === 'string') {
            status = receipt.status === '0x1' ? 1 : 0;
        } else {
            status = Number(receipt.status) ? 1 : 0;
        }
    } else if (receipt.root) {
        // Pre-Byzantium receipts used a state root instead of status
        status = receipt.root;
    } else {
        status = 0;
    }
    
    // Format logs - each log is [address, topics, data]
    const logs = receipt.logs.map((log: any) => [
        log.address,
        log.topics,
        log.data
    ]);
    
    // Prepare the receipt data array
    const receiptData = [
        status,
        receipt.cumulativeGasUsed,
        receipt.logsBloom,
        logs
    ];
    
    // Encode based on type
    if (type === 0) {
        // Legacy receipt - just RLP encode the data
        return RLP.encode(receiptData);
    } else if (type === 1) {
        // EIP-2930 receipt - prefix with 0x01
        const encodedReceipt = RLP.encode(receiptData);
        return Buffer.concat([Buffer.from([1]), encodedReceipt]);
    } else if (type === 2) {
        // EIP-1559 receipt - prefix with 0x02
        const encodedReceipt = RLP.encode(receiptData);
        return Buffer.concat([Buffer.from([2]), encodedReceipt]);
    } else if (type === 3) {
        // EIP-4844 receipt - prefix with 0x03
        const encodedReceipt = RLP.encode(receiptData);
        return Buffer.concat([Buffer.from([3]), encodedReceipt]);
    } else {
        throw new Error(`Unknown receipt type: ${type}`);
    }
}

function stripLeadingZeros(hex: string) {
    // Only strip if there are leading zeros after 0x
    if (/^0x0+/.test(hex)) {
        return "0x" + hex.replace(/^0x0+/, "");
    }
    return hex;
}

async function getTransactionProof(txHash: string, chainId: number) {
    // 1. Get Transaction Receipt
    const provider = new ethers.InfuraProvider(chainId, INFURA_API_KEY);
    const txRaw = await provider.getTransaction(txHash);    

    if (!txRaw) {
        console.error("Transaction not found");
        return;
    } else {
        if (LOGGING_ENABLED) {
            console.log("Transaction found");
        }
    }

    // 2. Get Block containing the transaction
    const block = await provider.send('eth_getBlockByNumber', [stripLeadingZeros(ethers.toBeHex(txRaw.blockNumber!)), true]);

    if (!block) {
        console.error("Block not found");
        return;
    }

    if (LOGGING_ENABLED) {
        console.log(`Found transaction at index ${txRaw.index} in block ${block.number}`);
        console.log("Block transactions root:", block.transactionsRoot);
    }

    // 3. Initialize a Merkle Patricia Trie
    const trie = new Trie();
    
    // Create a Common object for the chain
    const cId = await provider.getNetwork().then(network => network.chainId);
    const kzg = new microEthKZG(trustedSetup)

    const common = createCustomCommon({ chainId: Number(cId) }, Mainnet, { customCrypto: { kzg } })

    const txs = block.transactions;

    // 4. Insert Transactions into the Trie
    for (let i = 0; i < txs.length; i++) {
        const tx = txs[i];
        const key = RLP.encode(i);
        
        try {
            // Prepare transaction data
            const txData = {
                // Legacy fields
                nonce: tx.nonce,
                gasLimit: tx.gas,
                to: tx.to,
                value: tx.value,
                data: tx.input || tx.data || '0x',
                v: tx.v,
                r: tx.r,
                s: tx.s,
                type: tx.type,

                // EIP-2930 fields
                accessList: tx.accessList || [],
                chainId: tx.chainId || chainId,

                // EIP-1559 fields
                gasPrice: tx.gasPrice,
                maxPriorityFeePerGas: tx.maxPriorityFeePerGas,
                maxFeePerGas: tx.maxFeePerGas,

                // EIP-4844 fields
                blobVersionedHashes: tx.blobVersionedHashes || [],
                maxFeePerBlobGas: tx.maxFeePerBlobGas,
                
                // EIP-7702 fields
                authorizationList: tx.authorizationList || [],
            };

            // Use createTransaction for all types
            const txObj = createTx(txData, { common });
            const serializedTx = txObj.serialize();

            if (tx.hash !== ethers.keccak256(serializedTx)) {
                throw new Error("❌ Transaction hash mismatch");
            }

            // Add to trie
            await trie.put(key, serializedTx);
            
            // Log for debugging
            if (i === txRaw.index) {
                if (LOGGING_ENABLED) {
                    console.log(`Added target transaction ${tx.hash} at index ${i}`);
                }
            }
        } catch (error) {
            console.error(`Error serializing transaction at index ${i}:`, error);
            
            if (LOGGING_ENABLED) console.log('Transaction data:', tx);
            throw error; // Re-throw to stop execution and see the error
        }
    }

    // 5. Generate Proof
    const txIndex = RLP.encode(txRaw.index);
    const proof = await trie.createProof(txIndex);
    const value = await trie.get(txIndex);

    if (!proof || proof.length === 0) {
        console.error("❌ Failed to generate proof");
        return;
    }

    // 6. Validate the Trie Root matches Block Header
    const computedRoot = Buffer.from(trie.root()).toString('hex');
    if (LOGGING_ENABLED) {
        console.log(`Computed root: 0x${computedRoot}`);
        console.log(`Block transactions root: ${block.transactionsRoot}`);
    }

    if (`0x${computedRoot}` === block.transactionsRoot) {
        if (LOGGING_ENABLED) {
            console.log("✅ Computed Transactions Trie Root Matches Block Header");
        }
    } else {
        console.error("❌ Mismatch in Computed Transactions Root");
    }

    const txReceipt = await provider.getTransactionReceipt(txHash);

    if (!txReceipt) {
        console.error("❌ Transaction receipt not found");
        return;
    }

    if (txRaw.blockHash !== txReceipt.blockHash) {
        console.error("❌ Block hash mismatch");
        return;
    }

    if (txRaw.index !== txReceipt.index) {
        console.error("❌ Transaction index mismatch");
        return;
    }

    // 3. Initialize a Merkle Patricia Trie
    const receiptTrie = new Trie();

    // 4. Get all transaction receipts for the block
    const receipts = await provider.send(
        "eth_getBlockReceipts",
        [stripLeadingZeros(ethers.toBeHex(txRaw.blockNumber!))]
    );
    
    // 5. Insert receipts into the trie
    for (let i = 0; i < receipts.length; i++) {
        const txReceipt = receipts[i];
        const key = RLP.encode(i);
        
        // Encode receipt based on its type
        const encodedReceipt = encodeReceipt(txReceipt);
        
        // Add to trie
        await receiptTrie.put(key, encodedReceipt);
    }

    // 6. Generate Proof
    const receiptProof = await receiptTrie.createProof(txIndex);
    const receiptValue = await receiptTrie.get(txIndex);
    
    // 7. Validate the Trie Root matches Block Header
    const computedReceiptRoot = Buffer.from(receiptTrie.root()).toString('hex');
    if (LOGGING_ENABLED) {
        console.log(`Computed receipts root: 0x${computedReceiptRoot}`);
        console.log(`Block receipts root: ${block.receiptsRoot}`);
    }

    if (`0x${computedReceiptRoot}` === block.receiptsRoot) {
        if (LOGGING_ENABLED) console.log("✅ Computed Receipts Trie Root Matches Block Header");
    } else {
        console.error("❌ Mismatch in Computed Receipts Root");
    }

    return {
        txHash,
        txRaw,
        txReceipt,
        block,
        txProof: proof,
        txEncodedValue: value,
        receiptProof,
        receiptEncodedValue: receiptValue
    };
}

async function verifyTransactionProof(txHash: string, transactionIndex: number, block: any, proof: any, value: any) {
    
    // 1. The key is the RLP encoded transaction index
    const key = RLP.encode(transactionIndex);

    // 2. Convert the block's transactionsRoot to Buffer
    const expectedRoot = typeof block.transactionsRoot === 'string' && block.transactionsRoot.startsWith('0x')
        ? Buffer.from(block.transactionsRoot.slice(2), 'hex')
        : Buffer.from(block.transactionsRoot);
    // 3. Verify the proof using Trie.verifyProof
    try {
        // Verify the proof against the expected root
        const trie = new Trie()
        const verifiedValue = await trie.verifyProof(expectedRoot, key, proof);

        if (!verifiedValue) {
            console.error("❌ Proof verification failed - no value returned");
            return false;
        }
        
        // Check if the verified value matches the expected value
        const valueMatches = Buffer.compare(verifiedValue, value) === 0;
        
        if (!valueMatches) {
            console.error("❌ Proof verification failed - value mismatch");
            console.log("Expected:", value.toString());
            console.log("Got:", verifiedValue.toString());
            return false;
        }
        
        if (LOGGING_ENABLED) {
            console.log("✅ Proof verification successful!");
            console.log(`Transaction ${txHash} is confirmed to be in block`);
        }
        return true;
    } catch (error: any) {
        console.error("❌ Proof verification error:", error.message);
        return false;
    }
}


function serializeWithBigInt(obj: any) {
    return JSON.stringify(obj, (_, value) => {
        // Convert BigInt to string with numeric format
        if (typeof value === 'bigint') {
            return value.toString();
        }
        return value;
    });
}

// Example usage
async function getTransactionProofData(txHash: string, chainId: number) {
    try {
        const proofData = await getTransactionProof(txHash, chainId);
        if (!proofData) {
            throw new Error("Proof data not found");
        }

        const isValid = await verifyTransactionProof(
            proofData.txHash,
            proofData.txReceipt.index,
            proofData.block,
            proofData.txProof,
            proofData.txEncodedValue
        );

        if (!isValid) {
            throw new Error("Proof is invalid");
        }
    
        return serializeWithBigInt({
            TxHash: proofData.txHash,
            TxRoot: proofData.block.transactionsRoot,
            TxIndex: proofData.txReceipt.index.toString(),
            TxRaw: proofData.txRaw,
            TxReceipt: proofData.txReceipt,
            TxProof: proofData.txProof.map((n: any) => Array.from(n)),
            TxEncodedValue: Array.from(proofData.txEncodedValue!),
            ReceiptRoot: proofData.block.receiptsRoot,
            ReceiptProof: proofData.receiptProof.map((n: any) => Array.from(n)),
            ReceiptEncodedValue: Array.from(proofData.receiptEncodedValue!)
        });

    } catch (error) {
        console.error("Error:", error);
    }
}

export {
  getTransactionProofData,
  verifyTransactionProof,
}



// Example usage
// async function main() {
//   try {

//     console.log("txHash", txHash);

//     const proofData = await getTransactionProof(txHash);

//     if (proofData) {
//       const isValid = await verifyTransactionProof(proofData.txHash, proofData.txReceipt.transactionIndex, proofData.block, proofData.txProof, proofData.txEncodedValue);
//       console.log("Proof is valid:", isValid);

//       console.log(stringifyProofData(proofData));
//       // console.log(JSON.stringify({
//       //   TxHash: proofData.txHash,
//       //   TxRoot: proofData.block.transactionsRoot,
//       //   TxIndex: proofData.txReceipt.transactionIndex.toString(),
//       //   TxRaw: proofData.txRaw,
//       //   TxReceipt: proofData.txReceipt,
//       //   TxProof: proofData.txProof.map((n) => Array.from(n)),
//       //   TxEncodedValue: Array.from(proofData.txEncodedValue),
//       //   ReceiptRoot: proofData.block.receiptsRoot,
//       //   ReceiptProof: proofData.receiptProof.map((n) => Array.from(n)),
//       //   ReceiptEncodedValue: Array.from(proofData.receiptEncodedValue)
//       // }))
//     }
//   } catch (error) {
//     console.error("Error:", error);
//   }
// }

// main();