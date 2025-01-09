import { messageResult, readHandler, spawnProcess } from '@/permaweb';
import { Document, DocumentVC, DocumentSignature } from '@/permaweb/types';

export async function getDocumentById(documentId: string): Promise<Document | null> {
    try {
        const fetchedDocument = await readHandler({
            processId: documentId,
            action: 'Info',
            data: null,
        });

        if (fetchedDocument) {
            // If the VerifiableCredential is stored directly in the process
            if (fetchedDocument.VerifiableCredential) {
                return {
                    documentVC: fetchedDocument.VerifiableCredential,
                    isSigned: fetchedDocument.IsSigned || false
                };
            }

            // If we need to reconstruct the VC from individual fields
            const documentVC: DocumentVC = {
                '@context': ['https://www.w3.org/2018/credentials/v1'],
                type: ['VerifiableCredential', 'SignedAgreement'],
                credentialSubject: {
                    documentHash: fetchedDocument.DocumentHash,
                    timeStamp: fetchedDocument.TimeStamp,
                    id: fetchedDocument.Owner
                },
                issuer: { id: fetchedDocument.Owner },
                id: documentId,
                issuanceDate: fetchedDocument.TimeStamp,
                proof: {
                    type: 'JwtProof2020',
                    jwt: fetchedDocument.Signature || ''
                }
            };

            return {
                documentVC,
                isSigned: fetchedDocument.IsSigned || false
            };
        }
        return null;
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
            data: {
                // biome-ignore lint/style/useNamingConvention: AO convention
                Owner: documentVC.credentialSubject.id,
                // biome-ignore lint/style/useNamingConvention: AO convention
                DocumentHash: documentVC.credentialSubject.documentHash,
                // biome-ignore lint/style/useNamingConvention: AO convention
                Issuer: typeof documentVC.issuer === 'string' 
                    ? documentVC.issuer 
                    : documentVC.issuer.id,
                // biome-ignore lint/style/useNamingConvention: AO convention
                VerifiableCredential: documentVC,
                // biome-ignore lint/style/useNamingConvention: AO convention
                IsSigned: false,
                // biome-ignore lint/style/useNamingConvention: AO convention
                TimeStamp: documentVC.credentialSubject.timeStamp
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

export async function signDocument(
    counterSignature: DocumentSignature,
    processId: string,
    wallet: any
): Promise<boolean> {
    try {
        // Verify document exists first
        const document = await readHandler({
            processId,
            action: 'Info',
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
            data: {
                // biome-ignore lint/style/useNamingConvention: AO convention
                DocumentHash: counterSignature.counterSignatureVC.credentialSubject.originalDocumentHash,
                // biome-ignore lint/style/useNamingConvention: AO convention
                Signer: typeof counterSignature.counterSignatureVC.issuer === 'string' 
                    ? counterSignature.counterSignatureVC.issuer 
                    : counterSignature.counterSignatureVC.issuer.id,
                // biome-ignore lint/style/useNamingConvention: AO convention
                VerifiableCredential: counterSignature.counterSignatureVC,
                // biome-ignore lint/style/useNamingConvention: AO convention
                TimeStamp: counterSignature.counterSignatureVC.credentialSubject.timeStamp,
                // biome-ignore lint/style/useNamingConvention: AO convention
                OriginalVcId: counterSignature.counterSignatureVC.credentialSubject.originalVcId
            },
            tags: [],
        });

        return true;
    } catch (e: any) {
        throw new Error(`Failed to sign document: ${e.message}`);
    }
}