import { messageResult, readHandler, spawnProcess } from '@/permaweb';
import { AO } from '@/permaweb/config';
import { Document, DocumentSignature } from '@/permaweb/types';

export async function getDocumentById(documentId: string): Promise<Document | null> {
	try {
		const fetchedDocument = await readHandler({
			processId: documentId,
			action: 'Info',
			data: null,
		});

		if (fetchedDocument) {
			return {
				id: documentId,
                content: {
                    owner: fetchedDocument.Owner || null,
                    signer: fetchedDocument.Signer || null,
                },
                ownerSignature: fetchedDocument.OwnerSignature || null,
                isSigned: fetchedDocument.IsSigned || false,
			};
		} 
        return null;
	} catch (e: any) {
		throw new Error(e);
	}
}

export async function createDocument(document: Omit<Document, 'id'>, wallet: any): Promise<{ processId: string }> {
    try {
        // Create new AO process for the document
        const result = await spawnProcess({
            module: AO.module,
            wallet,
            data: {
                // biome-ignore lint/style/useNamingConvention: AO convention
                Owner: document.content.owner,
                // biome-ignore lint/style/useNamingConvention: AO convention
                OwnerSignature: document.ownerSignature,
                // biome-ignore lint/style/useNamingConvention: AO convention
                Signer: document.content.signer,
                // biome-ignore lint/style/useNamingConvention: AO convention
                IsSigned: false
            }
        });

        if (!result?.processId) {
            throw new Error('Failed to create document process');
        }

        return { processId: result.processId };
    } catch (e: any) {
        throw new Error(`Failed to create document: ${e.message}`);
    }
}

export async function signDocument(signature: DocumentSignature, wallet: any): Promise<boolean> {
    try {
        // Verify document exists first
        const document = await readHandler({
            processId: signature.documentId,
            action: 'Info',
            data: null,
        });

        if (!document) {
            throw new Error('Document not found');
        }

        // Send signature to the document process
        const result = await messageResult({
            processId: signature.documentId,
            wallet,
            action: 'Sign',
            data: {
                // biome-ignore lint/style/useNamingConvention: AO convention
                DocumentHash: signature.documentHash,
                // biome-ignore lint/style/useNamingConvention: AO convention
                Signer: signature.signer,
                // biome-ignore lint/style/useNamingConvention: AO convention
                Signature: signature.signature
            },
            tags: [],
        });

        return true;
    } catch (e: any) {
        throw new Error(`Failed to sign document: ${e.message}`);
    }
}