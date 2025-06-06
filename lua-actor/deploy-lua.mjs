#!/usr/bin/env node

import { createDataItemSigner, message, result, spawn } from '@permaweb/aoconnect';
import fs from 'fs';
import path from 'path';
import os from 'os';
import dotenv from 'dotenv';

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length === 0) {
    console.error('❌ Error: Please provide a bundle path');
    console.log('Usage: node deploy-lua.mjs <bundle-path>');
    console.log('Example: node deploy-lua.mjs src/apoc-v2-bundled.lua');
    process.exit(1);
}

const bundlePath = path.resolve(args[0]);

// Load environment variables from .env file
const envPath = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../.env');

if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
    console.log('📄 Loaded environment configuration from .env');
} else {
    console.warn('⚠️  .env file not found, using default environment');
}

// Standalone deployment function without internal dependencies
async function deployAOBundle(bundlePath, wallet) {
    try {
        console.log('🚀 Starting AO bundle deployment...');
        
        // Create new AO process
        console.log('📦 Creating new AO process...');
        const processId = await spawn({
            module: process.env.MODULE,
            scheduler: process.env.SCHEDULER,
            signer: createDataItemSigner(wallet),
            tags: [
                { name: 'DocumentType', value: 'AgreementDocument' },
                { name: 'Action', value: 'Eval' },
                { name: "Authority", value: process.env.MU },
            ],
            data: JSON.stringify({}),
        });

        if (!processId) {
            console.error('❌ Failed to create AO process');
            throw new Error('Failed to create AO process');
        }

        console.log(`✅ AO process created with ID: ${processId}`);

        // Read the Lua bundle from the specified path
        console.log(`📂 Reading Lua bundle from: ${bundlePath}`);
        let code = fs.readFileSync(bundlePath, 'utf-8');
        console.log(`📄 Bundle loaded, size: ${code.length} characters`);
        
        // Remove problematic lines that don't work in AO environment
        console.log('🔧 Cleaning bundle for AO environment...');
        const lines = code.split('\n');
        const cleanedLines = [];
        let skipMode = false;
        
        for (const line of lines) {
            if (line.includes('-- TODO: BEGIN remove lines')) {
                skipMode = true;
                continue;
            }
            if (line.includes('-- TODO: END remove lines')) {
                skipMode = false;
                continue;
            }
            if (!skipMode) {
                cleanedLines.push(line);
            }
        }
        
        code = cleanedLines.join('\n');
        console.log(`📄 Cleaned bundle, new size: ${code.length} characters`);

        // Send the actor code to the process
        console.log('🔧 Deploying actor code to AO process...');
        const txId = await message({
            process: processId,
            tags: [
                { name: "Action", value: "Eval" },
            ],
            signer: createDataItemSigner(wallet),
            data: code,
        });

        // Wait for the result
        console.log('⏳ Waiting for deployment result...');
        const response = await result({ message: txId, process: processId });

        if (response.Error) {
            throw new Error(`Deployment failed: ${response.Error}`);
        }

        console.log('✅ Actor code successfully deployed to AO process');
        console.log(`🎉 Deployment complete! Process ID: ${processId}`);

        return { 
            processId: processId, 
            success: true,
            txId: txId
        };
    } catch (e) {
        console.error(`❌ Failed to deploy AO bundle: ${e.message}`);
        throw new Error(`Failed to deploy AO bundle: ${e.message}`);
    }
}

async function main() {
    try {
        console.log(`🎯 Deploying bundle: ${bundlePath}`);
        console.log('⚠️  LIVE DEPLOYMENT MODE: This will cost real money!');
        
        // Load wallet from environment configuration
        const walletPath = process.env.WALLET_JSON_FILE;
        if (!walletPath) {
            console.error('❌ WALLET_JSON_FILE not found in environment variables');
            console.error('   Make sure your .env file contains: WALLET_JSON_FILE=~/.aos.json');
            process.exit(1);
        }
        
        // Expand tilde to home directory
        const expandedWalletPath = walletPath.startsWith('~') 
            ? path.resolve(os.homedir(), walletPath.slice(2)) // Remove ~/ (2 characters)
            : path.resolve(walletPath);
            
        console.log(`🔑 Loading wallet from: ${expandedWalletPath}`);
        
        if (!fs.existsSync(expandedWalletPath)) {
            console.error(`❌ Wallet file not found: ${expandedWalletPath}`);
            console.error('   Run "aos" first to generate wallet file, or check your WALLET_JSON_FILE path');
            process.exit(1);
        }
        
        const walletData = JSON.parse(fs.readFileSync(expandedWalletPath, 'utf-8'));
        console.log('✅ Wallet loaded successfully');
        
        // Verify required environment variables
        const requiredVars = ['MODULE', 'SCHEDULER', 'MU'];
        for (const varName of requiredVars) {
            if (!process.env[varName]) {
                console.error(`❌ ${varName} environment variable not set`);
                console.error(`   Add ${varName}=<value> to your .env file`);
                process.exit(1);
            }
        }
        
        console.log(`📋 Using MODULE: ${process.env.MODULE}`);
        console.log(`📋 Using SCHEDULER: ${process.env.SCHEDULER}`);
        console.log(`📋 Using MU: ${process.env.MU}`);
        
        // Check if bundle file exists
        if (!fs.existsSync(bundlePath)) {
            console.error(`❌ Bundle file not found: ${bundlePath}`);
            console.error('   Make sure the bundle path is correct');
            process.exit(1);
        }
        
        const deployResult = await deployAOBundle(bundlePath, walletData);
        
        console.log('\n🎉 Deployment Summary:');
        console.log(`   Process ID: ${deployResult.processId}`);
        console.log(`   Transaction ID: ${deployResult.txId}`);
        console.log(`   Success: ${deployResult.success}`);
        console.log(`   Bundle: ${bundlePath}`);
        console.log(`   Size: ${fs.readFileSync(bundlePath, 'utf-8').length} characters`);
        
        console.log('\n📋 Next Steps:');
        console.log(`   • Test your deployment: aos ${deployResult.processId}`);
        console.log(`   • View on ArConnect: https://ao.link/#/entity/${deployResult.processId}`);
        console.log('   • Check transaction status in a few minutes');
        
        console.log('\n💰 Cost Information:');
        console.log('   • Real AR tokens were spent for this deployment');
        console.log('   • Process creation and code deployment fees applied');
        console.log('   • Check your wallet balance if needed');
        
    } catch (error) {
        console.error('\n❌ Deployment failed:', error.message);
        
        console.log('\n🔧 Troubleshooting:');
        console.log('   • Check your .env file has all required variables');
        console.log('   • Verify wallet file exists and is valid');
        console.log('   • Ensure bundle file is valid Lua code');
        console.log('   • Check you have sufficient AR tokens');
        console.log('   • Verify network connectivity');
        
        process.exit(1);
    }
}

// Help function
function showHelp() {
    console.log('AO Lua Bundle Deployment Tool');
    console.log('');
    console.log('Usage: node deploy-lua.mjs <bundle-path>');
    console.log('');
    console.log('Arguments:');
    console.log('  bundle-path    Path to the Lua bundle file to deploy');
    console.log('');
    console.log('Examples:');
    console.log('  node deploy-lua.mjs src/apoc-v2-bundled.lua');
    console.log('  node deploy-lua.mjs ../my-actor.lua');
    console.log('');
    console.log('Environment:');
    console.log('  Requires .env file with:');
    console.log('    WALLET_JSON_FILE=~/.aos.json');
    console.log('    MODULE=<module-id>');
    console.log('    SCHEDULER=<scheduler-id>');
    console.log('    MU=<mu-id>');
    console.log('');
    console.log('Note: This operation costs real AR tokens!');
}

// Handle help flags
if (args.includes('--help') || args.includes('-h')) {
    showHelp();
    process.exit(0);
}

// Run the deployment
main().catch(console.error);
