import { messageResult, readHandler, spawnProcess } from '@/permaweb';
import { AgreementVC, AgreementInputVC } from '@/permaweb/types';
import * as fs from 'node:fs/promises';
import { join } from 'node:path';

function getRootPath(): string {
    // In production, files are typically in the 'dist' directory
    // In development, they're in the project root
    return process.env.NODE_ENV === 'production' 
      ? join(process.cwd(), 'dist') 
      : join(process.cwd(), 'src') ;
  }

  // TODO: could define a type that describes the whole actor state being returned
export async function getAgreementStateById(agreementId: string): Promise<any> {
    try {
        const state = await readHandler({
            processId: agreementId,
            action: 'GetState',
            data: null,
        });

        return state;
    } catch (e: any) {
        throw new Error(`Failed to fetch agreement state: ${e.message}`);
    }
}

  // TODO: could define a type that describes the whole actor state being returned
  export async function getAgreementDocumentById(agreementId: string): Promise<any> {
    try {
        const state = await readHandler({
            processId: agreementId,
            action: 'GetDocument',
            data: null,
        });

        return state;
    } catch (e: any) {
        throw new Error(`Failed to fetch agreement document: ${e.message}`);
    }
}

export async function createAgreement(
    agreementVC: AgreementVC,
    wallet: any
): Promise<{ processId: string }> {
    try {
        // Create new AO process for the agreement
        const result = await spawnProcess({
            module: process.env.MODULE,
            wallet,
            data: null,
        });

        if (!result?.processId) {
            throw new Error('Failed to create agreement process');
        }

        // Get the code from local file system
        const path = join(getRootPath(), 'permaweb/ao/actors/apoc-v2-bundled.lua');
        const code = await fs.readFile(path, 'utf-8');

        // Send the actor code
        const res = await messageResult({
            processId: result.processId,
            wallet,
            action: 'Eval',
            data: code,
            tags: [],
        });

        // Store the agreement
        const agreementResult = await messageResult({
            processId: result.processId,
            wallet,
            action: 'Init',
            data: JSON.stringify(agreementVC),
            tags: [],
        });

        const processResult = { processId: result.processId, success: true }
        // Check for errors during agreement doc initialization
        if (agreementResult?.Init?.data && !agreementResult.Init.data.success) { 
            return { ...processResult, ...agreementResult.Init.data } // data should contain an 'error' field
        }
        return processResult;
    } catch (e: any) {
        throw new Error(`Failed to create agreement: ${e.message}`);
    }
}

export async function processInput(
    agreementId: string,
    inputId: string,
    inputValue: AgreementInputVC,
    wallet: any
) {
    try {
        // Verify document exists first
        const document = await readHandler({
            processId: agreementId,
            action: 'GetState',
            data: null,
        });
        if (!document) {
            throw new Error('Agreement not found');
        }

        // Send input to the agreement
        const result = await messageResult({
            processId: agreementId,
            wallet,
            action: 'ProcessInput',
            data: JSON.stringify({
                inputId: inputId,
                inputValue: inputValue
            }),
            tags: [],
        });
        return result?.ProcessInput?.data;
    } catch (e: any) {
        throw new Error(`Failed to process input: ${e.message}`);
    }
}