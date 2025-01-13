import { messageResult, readHandler, spawnProcess } from '@/permaweb';
import { Document, DocumentVC, DocumentSignatureVC } from '@/permaweb/types';

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
            data: documentVC,
            // data: {
            //     // biome-ignore lint/style/useNamingConvention: AO convention
            //     Owner: documentVC.credentialSubject.id,
            //     // biome-ignore lint/style/useNamingConvention: AO convention
            //     DocumentHash: documentVC.credentialSubject.documentHash,
            //     // biome-ignore lint/style/useNamingConvention: AO convention
            //     Issuer: typeof documentVC.issuer === 'string' 
            //         ? documentVC.issuer 
            //         : documentVC.issuer.id,
            //     // biome-ignore lint/style/useNamingConvention: AO convention
            //     VerifiableCredential: documentVC,
            //     // biome-ignore lint/style/useNamingConvention: AO convention
            //     IsSigned: false,
            //     // biome-ignore lint/style/useNamingConvention: AO convention
            //     TimeStamp: documentVC.credentialSubject.timeStamp
            // }
        });

        if (!result?.processId) {
            throw new Error('Failed to create document process');
        }

        // Send the actor code
        const codeUploadResult = await messageResult({
            processId: result.processId,
            wallet,
            action: 'Eval',
            data: `
                local state = { 
                    document = nil,
                    signature = nill
                }
                Handlers.add("StoreDocument", function(data)
                    state.document = data
                end)

                Handlers.add("SignDocument", function(data)
                    state.signature = data
                end)

                Handlers.add("RetrieveDocument", function(data)
                    return state.document
                end)

                Handlers.add("RetrieveSignature", function(data)
                    return state.signature
                end)
            `,
            tags: [],
        });

        console.log(codeUploadResult);

        // Store the document
        const docResult = await messageResult({
            processId: result.processId,
            wallet,
            action: 'StoreDocument',
            data: documentVC,
            tags: [],
        });
        console.log(docResult);

        // Retrieve the document to see if it worked
        const downloadResult = await messageResult({
            processId: result.processId,
            wallet,
            action: 'RetrieveDocument',
            data: null,
            tags: [],
        });
        console.log(downloadResult);

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
        const document = await messageResult({
            processId,
            wallet,
            action: 'GetDocument',
            tags: [],
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
                DocumentHash: counterSignatureVC.credentialSubject.originalDocumentHash,
                // biome-ignore lint/style/useNamingConvention: AO convention
                Signer: typeof counterSignatureVC.issuer === 'string' 
                    ? counterSignatureVC.issuer 
                    : counterSignatureVC.issuer.id,
                // biome-ignore lint/style/useNamingConvention: AO convention
                VerifiableCredential: counterSignatureVC,
                // biome-ignore lint/style/useNamingConvention: AO convention
                TimeStamp: counterSignatureVC.credentialSubject.timeStamp,
                // biome-ignore lint/style/useNamingConvention: AO convention
                OriginalVcId: counterSignatureVC.credentialSubject.originalVcId
            },
            tags: [],
        });

        return true;
    } catch (e: any) {
        throw new Error(`Failed to sign document: ${e.message}`);
    }
}

export async function test(wallet: any) {
    // Send the actor code
    const codeUploadResult = await messageResult({
        processId: 'WJDj96YM7qXgnynpGNRIJmG5ANUcfqKQJs5M5YgiibA',
        wallet,
        action: 'Eval',
        data: `
            local state = { 
                document = nil,
                signature = nill
            }
            Handlers.add("storeDocument", function(data)
                state.document = data
            end)

            Handlers.add("signDocument", function(data)
                state.signature = data
            end)

            Handlers.add("retrieveDocument", function(data)
                return state.document
            end)

            Handlers.add("retrieveSignature", function(data)
                return state.signature
            end)
        `,
        tags: [],
    });
}