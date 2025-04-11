import Web3 from "web3";
import { Trie } from "@ethereumjs/trie";

import { RLP } from "@ethereumjs/rlp";
import { hexToBytes } from "web3-utils";
import { createDataItemSigner, dryrun, message, result, results } from '@permaweb/aoconnect';
import { FeeMarketEIP1559Transaction, AccessListEIP2930Transaction, LegacyTransaction } from '@ethereumjs/tx';
import { Common } from '@ethereumjs/common';


const processId = "bLltq4IiXPRxQRVds85Dr4qR8_rto1g1VhLCZyvgaMw";
const action = "VerifyTx";
const tags = [];

const LINEA_SEPOLIA_RPC = 'https://linea-sepolia.infura.io/v3/6e392322fbf84de380fd4473b2b836fb';
const txHash = "0x9445f933860ef6d65fdaf419fcf8b0749f415c7cd0f82f8b420b10a776c5373e";
const MAINNET_RPC_URL = 'https://mainnet.infura.io/v3/2PsxeELm0cHAs0gW5dhLuLPtZDe';
const SEPOLIA_RPC = 'https://sepolia.infura.io/v3/6e392322fbf84de380fd4473b2b836fb';
const LINEA_RPC = 'https://linea-mainnet.infura.io/v3/6e392322fbf84de380fd4473b2b836fb';
const web3 = new Web3(MAINNET_RPC_URL);

// LINEA TXH (35 Transactions) 0x09c62029e5c5736c46a26d1f8a35b19a588cfc0313c6ac42f286ec50e0f8970d
// LINEA TXH (25 Transactions) 0x6b9a3b14b16bd500f21dda9730c51ccc3c2217de765f65488d6a653102fcb2de   
// LINEA TXH (24 Transactions) 0xb6315839816082e257939f39ddd746ec331803a4b85f1056c84f66d861421398 
// SEPOLIA TXH (24 Transactions) 0xca88e1c4628fa82ac2ac3c016e392ade0e82318de7cbf73f4059135096ed8219
// MAINNET TXH (49 transactions) 0x79bfb4cdb4bd5da74af17371dec0d5a8d8b2c440ef72fb2a9ba18d37ac829b7c
// MAINNET TXH (27 Transactions) 0xa8f202f9f2d7cd0120dd573b68d8bb4e97453c0affdb09b74e431447b1f2007c
// MAINNET TXH (330 Transactions) 0x9445f933860ef6d65fdaf419fcf8b0749f415c7cd0f82f8b420b10a776c5373e

/**
 * Encodes a transaction receipt according to Ethereum rules
 * @param {Object} receipt - The transaction receipt object
 * @returns {Buffer} - The RLP encoded receipt
 */
function encodeReceipt(receipt) {
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
    const logs = receipt.logs.map(log => [
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
    } else {
        throw new Error(`Unknown receipt type: ${type}`);
    }
}

async function getTransactionProof(txHash) {
    // 1. Get Transaction Receipt
    const txRaw = await web3.eth.getTransaction(txHash);
    if (!txRaw) {
        console.error("Transaction not found");
        return;
    } else {
        console.log("Transaction found");
    }

    // 2. Get Block containing the transaction
    const block = await web3.eth.getBlock(txRaw.blockHash, true);
    if (!block) {
        console.error("Block not found");
        return;
    }
    
    console.log(`Found transaction at index ${txRaw.transactionIndex} in block ${block.number}`);
    console.log("Block transactions root:", block.transactionsRoot);

    // 3. Initialize a Merkle Patricia Trie
    const trie = new Trie();
    
    // Create a Common object for the chain
    const chainId = await web3.eth.getChainId();
    const common = Common.custom({ chainId });

    // 4. Insert Transactions into the Trie
    for (let i = 0; i < block.transactions.length; i++) {
        const tx = block.transactions[i];
        const key = RLP.encode(i);
        
        // Normalize transaction type
        const txType = typeof tx.type === 'string' ? 
            parseInt(tx.type.slice(2), 16) : 
            (tx.type === undefined ? 0 : Number(tx.type));
        
        let serializedTx;
        
        try {
            // Prepare transaction data
            const txData = {
                nonce: tx.nonce,
                gasLimit: tx.gas,
                to: tx.to || undefined, // Convert empty to to undefined
                value: tx.value,
                data: tx.input || tx.data || '0x',
                v: tx.v,
                r: tx.r,
                s: tx.s,
                chainId: tx.chainId || chainId
            };
            
            // Create the appropriate transaction object based on type
            if (txType === 2) {
                // EIP-1559 transaction
                const eip1559TxData = {
                    ...txData,
                    maxPriorityFeePerGas: tx.maxPriorityFeePerGas,
                    maxFeePerGas: tx.maxFeePerGas,
                    accessList: tx.accessList || []
                };
                
                const eip1559Tx = FeeMarketEIP1559Transaction.fromTxData(eip1559TxData, { common });
                serializedTx = eip1559Tx.serialize();
            } else if (txType === 1) {
                // EIP-2930 transaction
                const eip2930TxData = {
                    ...txData,
                    gasPrice: tx.gasPrice,
                    accessList: tx.accessList || []
                };
                
                const eip2930Tx = AccessListEIP2930Transaction.fromTxData(eip2930TxData, { common });
                serializedTx = eip2930Tx.serialize();
            } else {
                // Legacy transaction
                const legacyTxData = {
                    ...txData,
                    gasPrice: tx.gasPrice
                };
                
                const legacyTx = LegacyTransaction.fromTxData(legacyTxData, { common });
                serializedTx = legacyTx.serialize();
            }
            
            // Add to trie
            await trie.put(key, serializedTx);
            
            // Log for debugging
            if (i === parseInt(txRaw.transactionIndex)) {
                console.log(`Added target transaction ${tx.hash} at index ${i}`);
            }
        } catch (error) {
            console.error(`Error serializing transaction at index ${i}:`, error);
            console.log('Transaction data:', JSON.stringify(tx, null, 2));
            throw error; // Re-throw to stop execution and see the error
        }
    }

    // 5. Generate Proof
    const txIndex = RLP.encode(parseInt(txRaw.transactionIndex));
    const proof = await trie.createProof(txIndex);
    const value = await trie.get(txIndex);

    if (!proof || proof.length === 0) {
        console.error("❌ Failed to generate proof");
        return;
    }

    // 6. Validate the Trie Root matches Block Header
    const computedRoot = Buffer.from(trie.root()).toString('hex');
    console.log(`Computed root: 0x${computedRoot}`);
    console.log(`Block transactions root: ${block.transactionsRoot}`);

    if (`0x${computedRoot}` === block.transactionsRoot) {
        console.log("✅ Computed Transactions Trie Root Matches Block Header");
    } else {
        console.error("❌ Mismatch in Computed Transactions Root");
        
        // Additional debugging information
        console.log(`Difference in length: ${computedRoot.length} vs ${block.transactionsRoot.slice(2).length}`);
        
        // Check if the first few transactions are serialized correctly
        for (let i = 0; i < Math.min(3, block.transactions.length); i++) {
            const tx = block.transactions[i];
            console.log(`Transaction ${i} hash: ${tx.hash}`);
            
            // Try to get the raw transaction
            try {
                const rawTx = await web3.eth.getTransaction(tx.hash);
                console.log(`Raw transaction ${i}:`, rawTx);
            } catch (e) {
                console.log(`Could not get raw transaction ${i}`);
            }
        }
    }

    const txReceipt = await web3.eth.getTransactionReceipt(txHash);

    if (txRaw.blockHash !== txReceipt.blockHash) {
        console.error("❌ Block hash mismatch");
        return;
    }

    if (txRaw.transactionIndex !== txReceipt.transactionIndex) {
        console.error("❌ Transaction index mismatch");
        return;
    }

    // 3. Initialize a Merkle Patricia Trie
    const receiptTrie = new Trie();

    // 4. Get all transaction receipts for the block
    const receipts = await Promise.all(
        block.transactions.map(tx => web3.eth.getTransactionReceipt(tx.hash))
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
    console.log(`Computed receipts root: 0x${computedReceiptRoot}`);
    console.log(`Block receipts root: ${block.receiptsRoot}`);

    if (`0x${computedReceiptRoot}` === block.receiptsRoot) {
        console.log("✅ Computed Receipts Trie Root Matches Block Header");
    } else {
        console.error("❌ Mismatch in Computed Receipts Root");
    }

    return {
        txHash,
        txRaw,
        txReceipt,
        block,
        proof: proof,
        value: value,
        txRaw: txRaw
    };
}

async function verifyTransactionProof(txHash, transactionIndex, block, proof, value) {
    
    // 1. The key is the RLP encoded transaction index
    const key = RLP.encode(parseInt(transactionIndex));

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
            console.log("Expected:", value.toString('hex'));
            console.log("Got:", verifiedValue.toString('hex'));
            return false;
        }
        
        console.log("✅ Proof verification successful!");
        console.log(`Transaction ${txHash} is confirmed to be in block`);
        return true;
    } catch (error) {
        console.error("❌ Proof verification error:", error.message);
        return false;
    }
}

let wallet = {"kty":"RSA","n":"kn9SBUk_TWSxEPi_l8F2nHxMtEW-QVnxituaH9bvRikCzaO8_TcGgVZOSD5Aj8cyUHBYUpEHiTUWUHXzfozH55DTOtY3ZtZnD3z-9iVa6jl9JrPgOzSHpaYxc66CX-ocOv7wnQXKFyUdvzXVkm6I4KaLQ8xCNZIbEspr9hXdggclE1dYAiKIdi-GbIfReeJ9FxrWcgI94wQBvdHWpzulp1JoXEOm6w4SHZo9yTBIgP__qD3kR3fQMYiIsYKzug8BmRfJoryzGo0d25eUQVQk0Dx654NUymmJLW7BPIm6jU2AFnSLug3R2TkhcSqUCW416sgFyC6smVU2BJT8ON9ke1KmBtXmiurglKF0rMc2ALdEXX4Mkb6WHThTVBs-bZv4GF7ggPq3dAPxGfRWhQ6jfqIdI65_Wh-VBxO-sxG37ZG6CdGInwkcOlCJYbxOc1dXFmHW5O64MjEepG0jpstHwMmboGtBo7QXLB_PjRzooA8ws6gJFXCpAXSK__FUyQd1dcYEq9uo9zm_ngVfgl6eIQi5EuBDOujr2wm0N_S3Oael9PzvRHWL8Hi23178Cn0PvY5QvI16KaLYPksr90e__CJ7M8P2_8o2Cda2GCSjiQ9a8FI10_Z3B-CCY5lvHHacMJ5uWna0OTSbGkSamPAeV87PBdCJAlvHNnZ5r6p6-Hk","e":"AQAB","d":"K6OuyLFVoJXeoyoeVLQGQ75JUSg3cRs8dztMkbCCrXk5Aw4EFcAG-Y8-mYmlzM6vX8Pfo5TdVFOSlpxUUP3Z7NK5AZ1feoxivfvjrWpaR0yhyd4qbSiMQd2cfJPe9Xh1OWPJRFU9qqBdWKDOQqUXtCgYczVNAc1IsFPJTlCcIAhF1Jmft18XHHGyzvC0h2TfE3tkpyigy9fdNvDjywRbJ9lGCjoC5qFV5yiTwDNYXckknLb3Ig0AYUkFQy-mn0WqGbM61vX0OnQQEWJ5gO5yWu-xQvbd0sAWY4jLGmACyOXtwoKsPtuwB8_bdO0UlSyV9h7ojgXNV43JHhtNeRmewiQ-DqQT_Y1qkzhlUZuw4f-JaP18zaj_eRNZv2i8DvYKaTBfSCrqdbAYa0TCYN2aoqppTLjBlt1RkbRJ1gAhmTLmp3Guf4ep5kvQTNi1Ym-a9McN39Tolrs_RIAvIErGrYNPFZ9fT1NHVbu5k2JRPs7Q4G4IiJ9ETqsGEDHyIwOTXn0CJO_SfD3QbdIU84vGm47Orq0g79ICSrEPuQDlsbqVULJc0Dtia6nF7mGIISilbjHn14ox4nZgIQipc4ppPuaBxseP3TpWuWwDBlPFolfoHjMf7n2mibTs6KZ5Ou6oaasXYcr4V4KUlMXczFgb4tr5NAuEHlhXtBu4tGOCwmM","p":"zTIBZotyL4-L3edonPVcreb8G5tenvChTJZaT5TAuGWZjw3ct7It5wzpG1yS2H8YocNZpY-55l7o9CyPP7C1oT2ja8Q20uxdKIefQb_Or1H2zxx8ghARAd0xmvI3t_di_2GJ-61UM1u4LwhRrQ6LU6JhqT-PV4IfKqNbzuC1WWyYD9SO3KDTR1m_Aq5PjZ2My6zf5mhFjz5yZmi8JHUI98mZLAFZg-Cbg2naTamXG2P1MK7AdLsR0T0miln74w2ZqAwQ1yqHVhK1lZKrAnUmSfolKR6xJgYZ6yrHmIAXPaMn2RRFsktEAiiB6HKGR2VxC2M7q4b-uqLMzPD8mcUDRw","q":"tsTVA1_f5p7skjafH674wTENImaQJNFaVzBkxbJfkQA6pyPPoXWUVpMK1kQ-QSMx729xliPd5T4hJCWUXSMPTvy7rjlpil-zbyno6b1sFIGCScqO40-7iMCdqYBmsN_dkgrruiXRM_-9M9dNAoUZndAlC3l-IMw4ky8p3j97GZA5lV7oci3BIsvKbe1mIab3a5o7zbcYRWje4WE8xVUweuWAWMmIxuYjBxMLfKwQHlWPSxIaLXWlB7IxUePwDWY59kxD10c85eGmHBaNJtmWr2UAYh-8lWfbbhlY9u-_2Wt7HD0LMlXLFd-ATFkIzknIHQdKcKRWELiDMBVIhniGPw","dp":"X6BkQrPN3RhaqGmFuVAnhuvUpdD8gbnGkfin0dqTDdxbee2N5RXminzbzeKQlNB2XDy79IpMqm2kxtZVU-s4WhJtrHVez2FT8OVzdKK84bui99ZguARgyKuayIkFKnjh6_463c1jJiQia9jGp43VpH5SYRu7455ChA5pZLoYCbqwCwCWK3_Ptrq-Z7NwY6D-0pSYK7qAYEdL7Sn2NE9OhJuxBG8Elo8AKngUQok8YIlu5Ocrzbq4jPigk21oE-Jsr4If_wZU1-oUMcaOZ7DMzUEEPGuPRxck0RG4vvtC2XjFw0bNTFADO7ZBBGEK7w75ZcMzNbbN05C3PPM55TeJVQ","dq":"qyMHqo89oj6xmf9XZF18Q7ngaJPM6Qy3IOkJkyyA289xHEwmATON4Lry7Msd1_RSr7aUj1eqURuqAKTHlaZckUOJoYvUzWLrK238z9E0wMa77siinyprmZNyjeLTRU95s2RScg0zJROUYFR7oZ5r7B-YcHQkrCVN3FPPSnH6nGc15C3oTfGV5TUZqXEfruceyjyzPt7w9R1LhZJ9SvGH4avAUGL1lfisV9V3bhfXR_Apqsuag3KjQt-R2vIqNwG_yGaFJ7FmzoJJ_gcHyJb5x-Y1Q6wf8246Q4-shBzecYF412o5b7px3VtYUSUVX8QqgzPueicHB8Ud4gorzO5SFQ","qi":"xDeip6rYtPdxcB__dt83KjITMAHHLP7YgIjgbecHEbEE8ttsItFquvs_Bfj8KHh8MH6H8Hq0LZ6CcHA0lB62i4vLe7VDJV-EZikEMIageGW4GUTDOIopPbhRd2pUi3Srtc_RqASIEWC4AK27c7l-veJis9vIPJPl7CHkUIQfFrool4tC_QCvcmbDmUAedvcPW1xBx-63Is679TifmdlbBpKeRxYpLh8ciefm2AS8a2Rs2uIXOQ6lLwGHMNCX6QF4KVcX-QCMN_hnpARXipSYHTKyh-kfn3ZtsgSOED_WloQzSixxI-4a5d01i2lMsniTvMou5Xlo5jRjm0Bzy9NVag"}

function serializeWithBigInt(obj) {
    return JSON.stringify(obj, (key, value) => {
        // Convert BigInt to string with numeric format
        if (typeof value === 'bigint') {
            return value.toString();
        }
        return value;
    });
}

// Example usage
async function main() {
    try {
        const proofData = await getTransactionProof(txHash);
        if (proofData) {
            const isValid = await verifyTransactionProof(proofData.txHash, proofData.txReceipt.transactionIndex, proofData.block, proofData.proof, proofData.value);
            console.log("Proof is valid:", isValid);
        }

        const txId = await message({
            process: processId,
            tags: [
                { name: "Action", value: action },
                ...(tags || []),
            ],
            signer: createDataItemSigner(wallet),
            data: JSON.stringify({
                TxHash: proofData.txHash,
                TxRoot: proofData.block.transactionsRoot,
                TxIndex: proofData.txReceipt.transactionIndex.toString(),
                Proof: proofData.proof.map((n) => Array.from(n)),
                Value: Array.from(proofData.value)
            }),
        });
    
        console.log(serializeWithBigInt({
            TxHash: proofData.txHash,
            TxRoot: proofData.block.transactionsRoot,
            TxIndex: proofData.txReceipt.transactionIndex.toString(),
            TxRaw: proofData.txRaw,
            TxReceipt: proofData.txReceipt,
            Proof: proofData.proof.map((n) => Array.from(n)),
            Value: Array.from(proofData.value)
        }))
        const response = await result({ message: txId, process: processId });
        console.log(response);
    } catch (error) {
        console.error("Error:", error);
    }
}

main();