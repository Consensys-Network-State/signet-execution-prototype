import { messageResult, readHandler, spawnProcess } from '@/permaweb';
import { DocumentVC, DocumentSignatureVC } from '@/permaweb/types';
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
export async function getDocumentById(documentId: string): Promise<any> {
    try {
        const state = await readHandler({
            processId: documentId,
            action: 'GetState',
            data: null,
        });

        return state;
    } catch (e: any) {
        throw new Error(`Failed to fetch document: ${e.message}`);
    }
}

export async function createDocument(
    documentVC: DocumentVC,
    wallet: any
): Promise<{ processId: string }> {
    try {
        // Create new AO process for the document
        const result = await spawnProcess({
            module: process.env.MODULE,
            wallet,
            data: null,
        });

        if (!result?.processId) {
            throw new Error('Failed to create document process');
        }

        // Get the code from local file system
        const path = join(getRootPath(), 'permaweb/ao/actors/apoc.lua');
        const code = await fs.readFile(path, 'utf-8');

        // Send the actor code
        const codeUploadResult = await messageResult({
            processId: result.processId,
            wallet,
            action: 'Eval',
            data: code,
            tags: [],
        });
        console.log(codeUploadResult);

        // Store the document
        const docResult = await messageResult({
            processId: result.processId,
            wallet,
            action: 'Init',
            data: JSON.stringify(documentVC),
            tags: [],
        });

        return { processId: result.processId };
    } catch (e: any) {
        throw new Error(`Failed to create document: ${e.message}`);
    }
}

export async function signDocument(
    counterSignatureVC: DocumentSignatureVC,
    processId: string,
    wallet: any
): Promise<boolean> {
    try {
        // Verify document exists first
        const document = await readHandler({
            processId,
            action: 'GetState',
            data: null,
        });

        if (!document) {
            throw new Error('Document not found');
        }

        // Send counter-signature to the document process
        const result = await messageResult({
            processId,
            wallet,
            action: 'Sign',
            data: JSON.stringify(counterSignatureVC),
            tags: [],
        });

        return true;
    } catch (e: any) {
        throw new Error(`Failed to sign document: ${e.message}`);
    }
}