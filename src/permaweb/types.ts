export type TagType = { name: string; value: string };

export type Document = {
    id: string;
    content: {
        owner: string;
        signer: string;
    }
    ownerSignature: string; // against the content hash
    isSigned: boolean;
};

export type DocumentSignature = {
    documentId: string;
    documentHash: string, // document content hash
    signer: string;
    signature: string;
};