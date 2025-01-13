let veramoModules: any = null;

export async function initializeVeramo() {
    if (veramoModules) return veramoModules;
    
    const [core, didResolver, credential, resolver, PkhDIDProvider, credentialIssuerEIP712 ] = await Promise.all([
        Function('return import("@veramo/core")')(),
        Function('return import("@veramo/did-resolver")')(),
        Function('return import("@veramo/credential-w3c")')(),
        Function('return import("did-resolver")')(),
        Function('return import("@veramo/did-provider-pkh")')(),
        Function('return import("@veramo/credential-eip712")')(),
    ]);

    veramoModules = { core, didResolver, credential, resolver, PkhDIDProvider, credentialIssuerEIP712};
    return veramoModules;
}