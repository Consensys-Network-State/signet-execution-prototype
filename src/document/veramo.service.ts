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
            
            const result = await this.agent.verifyCredential({
                credential: credential as W3CVerifiableCredential,
                fetchRemoteContexts: true
            });

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

            const resolver = new this.modules.resolver.Resolver({
                ...this.modules.keyDid.getResolver()
            });

            this.agent = this.modules.core.createAgent({
                plugins: [
                    new this.modules.credential.CredentialPlugin(),
                    new this.modules.didResolver.DIDResolverPlugin({
                        resolver
                    })
                ]
            });
        } catch (error) {
            console.error('Failed to create Veramo agent:', error);
            throw error;
        }
    }
}