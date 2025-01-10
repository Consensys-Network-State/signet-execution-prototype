// veramo-init.ts
let veramoModules: any = null;

export async function initializeVeramo() {
    if (veramoModules) return veramoModules;
    
    const [core, didResolver, credential, resolver, keyDid] = await Promise.all([
        Function('return import("@veramo/core")')(),
        Function('return import("@veramo/did-resolver")')(),
        Function('return import("@veramo/credential-w3c")')(),
        Function('return import("did-resolver")')(),
        Function('return import("key-did-resolver")')(),
    ]);

    veramoModules = { core, didResolver, credential, resolver, keyDid };
    return veramoModules;
}