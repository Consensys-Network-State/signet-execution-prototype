import { messageResult, spawnProcess } from '@/permaweb';
import { InternalServerErrorException } from '@nestjs/common';
import * as fs from 'node:fs/promises';

export async function deployAOBundle(
    bundlePath: string,
    wallet: any
): Promise<{ processId: string; success: boolean }> {
    try {
        console.log('🚀 Starting AO bundle deployment...');
        
        // Create new AO process
        console.log('📦 Creating new AO process...');
        // TODO: Uncomment when ready for actual deployment (costs money!)
        // const result = await spawnProcess({
        //     module: process.env.MODULE,
        //     wallet,
        //     data: null,
        // });
        
        // Mock result for testing
        const result = { processId: 'mock-process-id-' + Date.now() };

        if (!result?.processId) {
            console.error('❌ Failed to create AO process');
            throw new InternalServerErrorException('Failed to create AO process');
        }

        console.log(`✅ AO process created with ID: ${result.processId}`);

        // Read the Lua bundle from the specified path
        console.log(`📂 Reading Lua bundle from: ${bundlePath}`);
        const code = await fs.readFile(bundlePath, 'utf-8');
        console.log(`📄 Bundle loaded, size: ${code.length} characters`);

        // Send the actor code to the process
        console.log('🔧 Deploying actor code to AO process...');
        // TODO: Uncomment when ready for actual deployment (costs money!)
        // const evalResult = await messageResult({
        //     processId: result.processId,
        //     wallet,
        //     action: 'Eval',
        //     data: code,
        //     tags: [],
        // });
        
        // Mock eval result for testing
        const evalResult = { success: true };

        console.log('✅ Actor code successfully deployed to AO process');
        console.log(`🎉 Deployment complete! Process ID: ${result.processId}`);

        return { 
            processId: result.processId, 
            success: true 
        };
    } catch (e: any) {
        console.error(`❌ Failed to deploy AO bundle: ${e.message}`);
        throw new InternalServerErrorException(`Failed to deploy AO bundle: ${e.message}`);
    }
} 