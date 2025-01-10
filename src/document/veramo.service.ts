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

            // Add debug step to check DID resolution
            const did = 'did:pkh:eip155:1:0x1e8564A52fc67A68fEe78Fc6422F19c07cFae198';
            const resolution = await this.agent.resolveDid({ didUrl: did });
            console.log('DID Resolution result:', JSON.stringify(resolution, null, 2));


            const result = await this.agent.verifyCredential({
                credential: credential as W3CVerifiableCredential,
                fetchRemoteContexts: true
            });

            console.log(result);

            return {
                verified: result.verified,
                error: result.verified ? undefined : 'Credential verification failed'
            };
        } catch (error) {
            console.error('Verification error:', error);
            return {
                verified: false,
                error: error instanceof Error ? error.message : 'Unknown verification error'
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
                    new this.modules.credential.CredentialPlugin({
                        suites: ['EcdsaSecp256k1RecoverySignature2020']  // Explicitly add support for the signature type
                    }),
                    new this.modules.didResolver.DIDResolverPlugin({
                        ...this.modules.PkhDIDProvider.getDidPkhResolver(),
                        'eip155': async (did: string) => {
                            // Add debugging
                            console.log('Resolving EIP155 DID:', did);
                            return this.modules.PkhDIDProvider.getDidPkhResolver().resolve(did);
                        }
                    }),
                    new this.modules.keyManager.KeyManager({
                        store: new this.modules.keyManager.MemoryKeyStore(),
                        kms: {
                            local: new this.modules.keyManagementSystem.KeyManagementSystem({
                                // Explicitly enable ES256K
                                keyTypes: ['Secp256k1'],
                                operations: ['sign', 'verify']
                            })
                        }
                    }),
                    new this.modules.didManager.DIDManager({
                        store: new this.modules.didManager.MemoryDIDStore(),
                        defaultProvider: 'did:pkh',
                        providers: {
                            'did:pkh': new this.modules.PkhDIDProvider.PkhDIDProvider({
                                defaultKms: 'local',
                                chainId: '1',  // Explicitly set chainId for mainnet
                            })
                        }
                    }),
                ]
            });
        } catch (error) {
            console.error('Failed to create Veramo agent:', error);
            throw error;
        }
    }
}