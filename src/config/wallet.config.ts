import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { resolve } from 'node:path';

export default () => {
    let walletPath = process.env.WALLET_JSON_FILE;
    
    if (!walletPath) {
        throw new Error('WALLET_JSON_FILE environment variable is not set');
    }

    // Replace ~ with actual home directory if present
    if (walletPath.startsWith('~')) {
        walletPath = resolve(homedir(), walletPath.slice(2));
    }

    try {
        const walletJson = readFileSync(walletPath, 'utf-8');
        return {
            wallet: JSON.parse(walletJson)
        };
    } catch (error) {
        throw new Error(`Failed to load wallet file: ${error.message}`);
    }
};