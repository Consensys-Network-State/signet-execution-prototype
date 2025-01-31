import {
    VerifiableCredential,
    IssuerType
} from '@veramo/core'

interface DocumentCredentialSubject {
    id: string
    document?: string
    documentHash?: string
    timeStamp: string
    signatories?: string[]
}

interface DocumentVC extends Omit<VerifiableCredential, 'issuer' | 'type' | '@context' | 'credentialSubject'> {
    '@context': ['https://www.w3.org/2018/credentials/v1']
    type: ['VerifiableCredential', 'Agreement' | 'SignedAgreement']
    credentialSubject: DocumentCredentialSubject
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

interface Document {
    documentVC: DocumentVC
    isSigned: boolean
}

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

export type TagType = { name: string; value: string };

export type {
    Document,
    DocumentVC,
    DocumentSignatureVC,
    DocumentCredentialSubject,
    CounterSignatureCredentialSubject
}