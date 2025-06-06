#!/usr/bin/env node

import { createDataItemSigner, message, result } from '@permaweb/aoconnect';
import fs from 'fs';
import path from 'path';
import os from 'os';
import dotenv from 'dotenv';

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length < 2) {
    console.error('❌ Error: Please provide both process ID and JSON file path');
    console.log('Usage: node initialize-agreement.mjs <process-id> <json-file-path>');
    console.log('Example: node initialize-agreement.mjs CCcEFJ66jxvCboCohz-Vj7aO3BCeEIkHxwhYtaYV7sM ./tests/manifesto/wrapped/manifesto.wrapped.json');
    process.exit(1);
}

const processId = args[0];
const jsonFilePath = path.resolve(args[1]);

// Load environment variables from .env file
const envPath = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../.env');

if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
    console.log('📄 Loaded environment configuration from .env');
} else {
    console.warn('⚠️  .env file not found, using default environment');
}

async function initializeAgreement(processId, agreementVC, wallet) {
    try {
        console.log('📋 Initializing agreement...');
        
        // Send the agreement VC to initialize the process
        const txId = await message({
            process: processId,
            tags: [
                { name: "Action", value: "Init" },
            ],
            signer: createDataItemSigner(wallet),
            data: JSON.stringify(agreementVC),
        });

        console.log(`📤 Sent initialization message, transaction ID: ${txId}`);

        // Wait for the result
        console.log('⏳ Waiting for initialization result...');
        const response = await result({ message: txId, process: processId });

        console.log('📥 Received response:', JSON.stringify(response, null, 2));

        // Check for success based on documents.ts logic
        if (response?.Init?.data && !response.Init.data.success) {
            console.error('❌ Agreement initialization failed');
            return { ...{ processId, success: false }, ...response.Init.data };
        }

        if (response.Error) {
            console.error('❌ Error during initialization:', response.Error);
            throw new Error(`Initialization failed: ${response.Error}`);
        }

        console.log('✅ Agreement successfully initialized');
        return { processId, success: true };

    } catch (e) {
        console.error(`❌ Failed to initialize agreement: ${e.message}`);
        throw new Error(`Failed to initialize agreement: ${e.message}`);
    }
}

async function main() {
    try {
        console.log(`🎯 Initializing agreement for process: ${processId}`);
        console.log(`📂 Using JSON file: ${jsonFilePath}`);
        
        // Load wallet from environment configuration
        const walletPath = process.env.WALLET_JSON_FILE;
        if (!walletPath) {
            console.error('❌ WALLET_JSON_FILE not found in environment variables');
            console.error('   Make sure your .env file contains: WALLET_JSON_FILE=~/.aos.json');
            process.exit(1);
        }
        
        // Expand tilde to home directory
        const expandedWalletPath = walletPath.startsWith('~') 
            ? path.resolve(os.homedir(), walletPath.slice(2))
            : path.resolve(walletPath);
            
        console.log(`🔑 Loading wallet from: ${expandedWalletPath}`);
        
        if (!fs.existsSync(expandedWalletPath)) {
            console.error(`❌ Wallet file not found: ${expandedWalletPath}`);
            console.error('   Run "aos" first to generate wallet file, or check your WALLET_JSON_FILE path');
            process.exit(1);
        }
        
        const walletData = JSON.parse(fs.readFileSync(expandedWalletPath, 'utf-8'));
        console.log('✅ Wallet loaded successfully');
        
        // Check if JSON file exists
        if (!fs.existsSync(jsonFilePath)) {
            console.error(`❌ JSON file not found: ${jsonFilePath}`);
            console.error('   Make sure the file path is correct');
            process.exit(1);
        }
        
        // Load and parse the agreement VC JSON
        console.log(`📄 Loading agreement VC from: ${jsonFilePath}`);
        const agreementVC = JSON.parse(fs.readFileSync(jsonFilePath, 'utf-8'));
        console.log('✅ Agreement VC loaded successfully');
        
        // Validate basic structure
        if (!agreementVC.credentialSubject || !agreementVC.credentialSubject.agreement) {
            console.error('❌ Invalid agreement VC: missing credentialSubject.agreement');
            process.exit(1);
        }
        
        console.log(`📋 Agreement ID: ${agreementVC.credentialSubject.id || 'N/A'}`);
        console.log(`👤 Issuer: ${agreementVC.issuer?.id || 'N/A'}`);
        
        const initResult = await initializeAgreement(processId, agreementVC, walletData);
        
        console.log('\n🎉 Initialization Summary:');
        console.log(`   Process ID: ${initResult.processId}`);
        console.log(`   Success: ${initResult.success}`);
        console.log(`   JSON File: ${jsonFilePath}`);
        
        if (initResult.success) {
            console.log('\n📋 Next Steps:');
            console.log(`   • Test your agreement: aos ${processId}`);
            console.log(`   • Check state: Send({ Target = "${processId}", Action = "GetState" })`);
            console.log(`   • View on ArConnect: https://ao.link/#/entity/${processId}`);
        } else {
            console.log('\n❌ Initialization failed. Check the error details above.');
            if (initResult.error) {
                console.log(`   Error: ${initResult.error}`);
            }
        }
        
        console.log('\n💰 Cost Information:');
        console.log('   • Real AR tokens were spent for this message');
        console.log('   • Check your wallet balance if needed');
        
    } catch (error) {
        console.error('\n❌ Initialization failed:', error.message);
        
        console.log('\n🔧 Troubleshooting:');
        console.log('   • Verify the process ID is valid and deployed');
        console.log('   • Check the JSON file is valid agreement VC format');
        console.log('   • Ensure wallet file exists and is valid');
        console.log('   • Verify you have sufficient AR tokens');
        console.log('   • Check network connectivity');
        
        process.exit(1);
    }
}

// Help function
function showHelp() {
    console.log('AO Agreement Initialization Tool');
    console.log('');
    console.log('Usage: node initialize-agreement.mjs <process-id> <json-file-path>');
    console.log('');
    console.log('Arguments:');
    console.log('  process-id      The AO process ID to initialize');
    console.log('  json-file-path  Path to the JSON file containing the agreement VC');
    console.log('');
    console.log('Examples:');
    console.log('  node initialize-agreement.mjs CCcEFJ66jxvCboCohz-Vj7aO3BCeEIkHxwhYtaYV7sM ./tests/manifesto/wrapped/manifesto.wrapped.json');
    console.log('  node initialize-agreement.mjs abc123def456 ../my-agreement.json');
    console.log('');
    console.log('Environment:');
    console.log('  Requires .env file with:');
    console.log('    WALLET_JSON_FILE=~/.aos.json');
    console.log('');
    console.log('Note: This operation costs real AR tokens!');
}

// Handle help flags
if (args.includes('--help') || args.includes('-h')) {
    showHelp();
    process.exit(0);
}

// Run the initialization
main().catch(console.error); 