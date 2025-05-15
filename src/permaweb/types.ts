import {
    VerifiableCredential,
    IssuerType
} from '@veramo/core'

interface CounterSignatureCredentialSubject {
    id: string
    documentHash: string
    signatureBlocks: string
    timeStamp: string
}

interface DocumentSignatureVC extends Omit<VerifiableCredential, 'issuer' | 'type' | '@context' | 'credentialSubject'> {
    '@context': ['https://www.w3.org/2018/credentials/v1']
    type: ['VerifiableCredential', 'CounterSignature']
    credentialSubject: CounterSignatureCredentialSubject
    issuer: IssuerType
    issuanceDate: string
    proof: {
        type: 'EthereumEip712Signature2021'
        jwt?: string
        verificationMethod: string
        created: string
        proofPurpose: string
        proofValue: string
        eip712: {
            domain: {
                chainId: number
                name: string
                version: string
            }
            types: {
                EIP712Domain: Array<{
                    name: string
                    type: string
                }>
                CredentialSubject: Array<{
                    name: string
                    type: string
                }>
                Issuer: Array<{
                    name: string
                    type: string
                }>
                Proof: Array<{
                    name: string
                    type: string
                }>
                VerifiableCredential: Array<{
                    name: string
                    type: string
                }>
            }
            primaryType: string
        }
    }
}

interface AgreementCredentialSubject {
    id: string
    agreement: string
    params?: {
        [key: string]: any
    }
}

interface AgreementVC extends Omit<VerifiableCredential, 'issuer' | 'type' | '@context' | 'credentialSubject'> {
    '@context': ['https://www.w3.org/2018/credentials/v1']
    type: ['VerifiableCredential', 'AgreementCredential']
    credentialSubject: AgreementCredentialSubject
    issuer: IssuerType
    issuanceDate: string
    proof: {
        type: 'EthereumEip712Signature2021'
        jwt?: string
        verificationMethod: string
        created: string
        proofPurpose: string
        proofValue: string
        eip712: {
            domain: {
                chainId: number
                name: string
                version: string
            }
            types: {
                EIP712Domain: Array<{
                    name: string
                    type: string
                }>
                CredentialSubject: Array<{
                    name: string
                    type: string
                }>
                Params?: Array<{
                    name: string
                    type: string
                }>
                Issuer: Array<{
                    name: string
                    type: string
                }>
                Proof: Array<{
                    name: string
                    type: string
                }>
                VerifiableCredential: Array<{
                    name: string
                    type: string
                }>
            }
            primaryType: string
        }
    }
}

interface AgreementInputCredentialSubject {
    id: string
    type: string
    values: {
        [key: string]: any
    }
}

interface AgreementInputVC extends Omit<VerifiableCredential, 'issuer' | 'type' | '@context' | 'credentialSubject'> {
    '@context': ['https://www.w3.org/2018/credentials/v1']
    type: ['VerifiableCredential', 'AgreementInputCredential']
    credentialSubject: AgreementInputCredentialSubject
    issuer: IssuerType
    issuanceDate: string
    proof: {
        type: 'EthereumEip712Signature2021'
        jwt?: string
        verificationMethod: string
        created: string
        proofPurpose: string
        proofValue: string
        eip712: {
            domain: {
                chainId: number
                name: string
                version: string
            }
            types: {
                EIP712Domain: Array<{
                    name: string
                    type: string
                }>
                CredentialSubject: Array<{
                    name: string
                    type: string
                }>
                Values: Array<{
                    name: string
                    type: string
                }>
                Issuer: Array<{
                    name: string
                    type: string
                }>
                Proof: Array<{
                    name: string
                    type: string
                }>
                VerifiableCredential: Array<{
                    name: string
                    type: string
                }>
            }
            primaryType: string
        }
    }
}

export type TagType = { name: string; value: string };

export interface AgreementState {
    State: {
        id: string;
        name: string;
        description: string;
        isInitial: boolean;
    };
    IsComplete: boolean;
    Variables: Record<string, {
        value: any;
        type: string;
        name: string;
        description: string;
    }>;
    Inputs: Record<string, any>;
}

export interface AgreementRecord {
    id: string;
    document: any; // AgreementVC or similar
    documentHash: string;
    state: AgreementState;
    contributors: string[];
    createdAt: Date;
    updatedAt: Date;
}

export type {
    DocumentSignatureVC,
    CounterSignatureCredentialSubject,
    AgreementVC,
    AgreementCredentialSubject,
    AgreementInputVC,
    AgreementInputCredentialSubject,
}