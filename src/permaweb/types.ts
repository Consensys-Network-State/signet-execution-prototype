import {
    VerifiableCredential,
    IssuerType
} from '@veramo/core'

interface DocumentCredentialSubject {
    documentHash: string
    timeStamp: string
    id: string
}

interface DocumentVC extends Omit<VerifiableCredential, 'issuer' | 'type' | '@context' | 'credentialSubject'> {
    '@context': ['https://www.w3.org/2018/credentials/v1']
    type: ['VerifiableCredential', 'SignedAgreement']
    credentialSubject: DocumentCredentialSubject
    issuer: IssuerType
    proof: {
        type: 'JwtProof2020'
        jwt: string
    }
}

interface Document {
    documentVC: DocumentVC
    isSigned: boolean
}

interface CounterSignatureCredentialSubject {
    originalDocumentHash: string
    originalVcId: string
    timeStamp: string
    id: string
}

interface CounterSignatureVC extends Omit<VerifiableCredential, 'issuer' | 'type' | '@context' | 'credentialSubject'> {
    '@context': ['https://www.w3.org/2018/credentials/v1']
    type: ['VerifiableCredential', 'CounterSignature']
    credentialSubject: CounterSignatureCredentialSubject
    issuer: IssuerType
    proof: {
        type: 'JwtProof2020'
        jwt: string
    }
}

interface DocumentSignature {
    counterSignatureVC: CounterSignatureVC
    isSigned: boolean
}

export type {
    Document,
    DocumentVC,
    DocumentSignature,
    CounterSignatureVC,
}

export type TagType = { name: string; value: string };