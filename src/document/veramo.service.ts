import { DocumentVC, DocumentSignatureVC } from '@/permaweb/types';
import { Injectable } from '@nestjs/common';
import type {
    ICredentialVerifier,
    W3CVerifiableCredential,
} from '@veramo/core';

type VerificationResult = {
    verified: boolean;
    error?: string;
};

@Injectable()
export class VeramoService {
    private agent: any = null;
    private modules: any = null;

    async verifyCredential(credential: DocumentVC | DocumentSignatureVC): Promise<VerificationResult> {
        try {
            if (!this.agent) {
                await this.initializeAgent();
            }
    
            console.log('Credential to verify:', JSON.stringify(credential, null, 2));
            console.log('JWT to verify:', credential.proof.jwt);
    
            const issuerDid = typeof credential.issuer === 'string' 
                ? credential.issuer 
                : credential.issuer.id;
    
            const didDoc = await this.agent.resolveDid({ 
                didUrl: issuerDid,
                options: { 
                    publicKeyFormat: ['ES256K', 'Secp256k1', 'EcdsaSecp256k1RecoveryMethod2020'],
                    accept: 'application/did+ld+json'
                }
            });
            console.log('Resolved DID Document:', JSON.stringify(didDoc, null, 2));
    
            const result = await this.agent.verifyCredential({
                credential: credential as W3CVerifiableCredential,
                fetchRemoteContexts: true,
                policies: {
                    now: new Date('2025-01-10T18:41:00.214Z'),
                    credentialStatus: false
                },
                verification: {
                    // Add specific verification options
                    jwt: {
                        algorithms: ['ES256K'],
                        audience: credential.credentialSubject.id
                    },
                    verificationMethod: {
                        publicKeyFormat: 'ES256K',
                        methods: ['ES256K', 'EcdsaSecp256k1RecoveryMethod2020'],
                        recovery: true
                    }
                }
            });
    
            console.log('Full verification result:', JSON.stringify(result, null, 2));
    
            return {
                verified: result.verified,
                error: result.verified ? undefined : `Credential verification failed: ${JSON.stringify(result.error)}`
            };
        } catch (error) {
            console.error('Verification error:', error);
            if (error instanceof Error) {
                console.error('Full error stack:', error.stack);
            }
            return {
                verified: false,
                error: error instanceof Error ? 
                    `${error.name}: ${error.message}` : 
                    'Unknown verification error'
            };
        }
    }

    private async initializeAgent() {
        try {
            if (!this.modules) {
                const { initializeVeramo } = await import('./veramo-init');
                this.modules = await initializeVeramo();
            }

            this.agent = this.modules.core.createAgent({
                plugins: [
                    new this.modules.credential.CredentialPlugin(),
                    new this.modules.didResolver.DIDResolverPlugin({
                        resolver: new this.modules.resolver.Resolver({
                            ...this.modules.PkhDIDProvider.getDidPkhResolver()
                        })
                    }),
                    new this.modules.credentialIssuerEIP712.CredentialIssuerEIP712()
                    
                ]
            });
        } catch (error) {
            console.error('Failed to create Veramo agent:', error);
            throw error;
        }
    }
}