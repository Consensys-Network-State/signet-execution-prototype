/* adder_lua.c - Lua module wrapper for the adder library */
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <stdarg.h>
#include <string.h>
#include "secp256k1.h"
#include "secp256k1_recovery.h"
// #include "adder.h"

// Included a sha256 implementation to avoid having to include openssl
void sha256(const unsigned char *data, size_t len, unsigned char *out);

// Utility function to print to Lua
int lua_print(lua_State* L, const char* message) {  
    // Push the print function from the global environment
    lua_getglobal(L, "print");

    // Push the message string
    lua_pushstring(L, message);

    // Call print function with 1 argument, 0 return values
    if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
        // Handle error if print fails
        fprintf(stderr, "Error calling print: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    return 0;
}

// Utility function to print to Lua
void lua_printf(lua_State *L, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);

    // Calculate required buffer size
    va_list args_copy;
    va_copy(args_copy, args);
    int size = vsnprintf(NULL, 0, fmt, args_copy);
    va_end(args_copy);

    if (size < 0) {
        va_end(args);
        return;
    }

    // Allocate buffer with space for null terminator
    char *buffer = (char *)malloc(size + 1);
    if (!buffer) {
        va_end(args);
        return;
    }

    // Format the string
    vsnprintf(buffer, size + 1, fmt, args);

    // Get print function from Lua global state
    lua_getglobal(L, "print");

    // Push formatted string as argument
    lua_pushstring(L, buffer);

    // Call Lua print function
    if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
        fprintf(stderr, "Error calling Lua print: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    // Clean up
    free(buffer);
    va_end(args);
}

  static void* safe_calloc(size_t num_elements, size_t element_size) {
    void* ptr = calloc(num_elements, element_size);
    if (!ptr) {
        return NULL;
    }
    return ptr;
}

  // Utility function to convert hex string to byte array with proper allocation
static unsigned char* hex_to_bytes(const char* hex, size_t* out_len, lua_State* L) {
    size_t hex_len = strlen(hex);

    if (hex_len % 2 != 0) {
        return NULL;  // Invalid hex string length
    }

    size_t bytes_len = hex_len / 2;
    unsigned char* bytes = (unsigned char*)safe_calloc(bytes_len, sizeof(unsigned char));
    if (!bytes) {
        return NULL;
    }

    for (size_t i = 0; i < bytes_len; i++) {
        char byte_hex[3] = {hex[i*2], hex[i*2 + 1], '\0'};
        bytes[i] = (unsigned char)strtol(byte_hex, NULL, 16);
    }

    if (out_len) {
        *out_len = bytes_len;
    }

    return bytes;
}

// Safe cleanup helper
static void cleanup_memory(void** ptrs, size_t num_ptrs) {
    for (size_t i = 0; i < num_ptrs; i++) {
        if (ptrs[i]) {
            free(ptrs[i]);
            ptrs[i] = NULL;
        }
    }
}

static int is_der_signature(const unsigned char* sig, size_t len) {
    // Basic DER signature checks:
    // 1. Minimum length for DER signature (7 bytes)
    // 2. Starts with 0x30 (SEQUENCE)
    // 3. Second byte is length
    // 4. Two INTEGER markers (0x02)
    if (len < 7 || sig[0] != 0x30) {
        return 0;
    }

    // Check if total length matches DER length byte
    size_t stated_len = sig[1];
    if (stated_len > len - 2) {  // -2 for header bytes
        return 0;
    }

    // Check for INTEGER markers
    if (sig[2] != 0x02) {
        return 0;
    }

    // Find second INTEGER marker
    size_t first_int_len = sig[3];
    if (4 + first_int_len >= len || sig[4 + first_int_len] != 0x02) {
        return 0;
    }

    return 1;
}

static int lua_verify_signature(lua_State* L) {
    void* cleanup_ptrs[4] = {NULL};
    size_t cleanup_count = 0;

    // Get and validate inputs
    const char* message_str = luaL_checkstring(L, 1);
    const char* sig_hex_str = luaL_checkstring(L, 2);
    const char* pubkey_hex_str = luaL_checkstring(L, 3);

    // Allocate message hash
    unsigned char* message_hash = (unsigned char*)safe_calloc(32, sizeof(unsigned char));
    if (!message_hash) {
        lua_print(L, "Memory allocation failed for message hash");
        lua_pushinteger(L, -1);
        return 1;
    }
    cleanup_ptrs[cleanup_count++] = message_hash;

    // Hash the message
    sha256((const unsigned char*)message_str, strlen(message_str), message_hash);

    // Convert signature from hex
    size_t sig_len = 0;
    unsigned char* signature = hex_to_bytes(sig_hex_str, &sig_len, L);
    if (!signature) {
        cleanup_memory(cleanup_ptrs, cleanup_count);
        lua_print(L, "Failed to decode signature hex");
        lua_pushinteger(L, -1);
        return 1;
    }
    cleanup_ptrs[cleanup_count++] = signature;

    // Detect signature format
    int is_der = is_der_signature(signature, sig_len);

    // Validate signature length based on format
    if (!is_der && sig_len != 64) {
        cleanup_memory(cleanup_ptrs, cleanup_count);
        lua_print(L, "Raw signature must be exactly 64 bytes");
        lua_pushinteger(L, -1);
        return 1;
    }

    // Convert public key from hex
    size_t pubkey_len = 0;
    unsigned char* pubkey = hex_to_bytes(pubkey_hex_str, &pubkey_len, L);
    if (!pubkey) {
        cleanup_memory(cleanup_ptrs, cleanup_count);
        lua_print(L, "Failed to decode public key hex");
        lua_pushinteger(L, -1);
        return 1;
    }
    cleanup_ptrs[cleanup_count++] = pubkey;

    // Create and verify the secp256k1 context
    secp256k1_context* ctx = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY);
    if (!ctx) {
        cleanup_memory(cleanup_ptrs, cleanup_count);
        lua_print(L, "Failed to create secp256k1 context");
        lua_pushinteger(L, -1);
        return 1;
    }
    cleanup_ptrs[cleanup_count++] = ctx;

    // Parse the signature according to its format
    secp256k1_ecdsa_signature sig;
    int sig_parse_result;

    if (is_der) {
        sig_parse_result = secp256k1_ecdsa_signature_parse_der(ctx, &sig, signature, sig_len);
        if (sig_parse_result != 1) {
            cleanup_memory(cleanup_ptrs, cleanup_count);
            lua_print(L, "Failed to parse DER signature");
            lua_pushinteger(L, -1);
            return 1;
        }
    } else {
        sig_parse_result = secp256k1_ecdsa_signature_parse_compact(ctx, &sig, signature);
        if (sig_parse_result != 1) {
            cleanup_memory(cleanup_ptrs, cleanup_count);
            lua_print(L, "Failed to parse raw signature");
            lua_pushinteger(L, -1);
            return 1;
        }
    }

    // Validate public key format
    if (pubkey_len != 33) {
        cleanup_memory(cleanup_ptrs, cleanup_count);
        lua_print(L, "Public key must be 33 bytes (compressed format)");
        lua_pushinteger(L, -1);
        return 1;
    }

    if (pubkey[0] != 0x02 && pubkey[0] != 0x03) {
        cleanup_memory(cleanup_ptrs, cleanup_count);
        lua_print(L, "Public key must start with 0x02 or 0x03 (compressed format)");
        lua_pushinteger(L, -1);
        return 1;
    }

    // Parse the public key
    secp256k1_pubkey pubkey_obj;
    int pubkey_parse_result = secp256k1_ec_pubkey_parse(ctx, &pubkey_obj, pubkey, pubkey_len);
    if (pubkey_parse_result != 1) {
        cleanup_memory(cleanup_ptrs, cleanup_count);
        lua_print(L, "Failed to parse public key");
        lua_pushinteger(L, -1);
        return 1;
    }

    // Verify the signature
    int verify_result = secp256k1_ecdsa_verify(ctx, &sig, message_hash, &pubkey_obj);

    // Clean up the context
    secp256k1_context_destroy(ctx);
    cleanup_ptrs[3] = NULL;
    cleanup_count--;

    // Clean up allocated memory
    cleanup_memory(cleanup_ptrs, cleanup_count);

    // Return verification result: 1 for success, 0 for invalid signature
    lua_pushboolean(L, verify_result == 1);
    return 1;
}


static int recover_public_key(lua_State* L) {
    // Get parameters from Lua stack
    const char* sig_hex = luaL_checkstring(L, 1);     // 65 bytes signature in hex (130 chars)
    const char* msg_hash_hex = luaL_checkstring(L, 2); // 32 bytes message hash in hex (64 chars)
    int cleanup = lua_toboolean(L, 3);                // optional cleanup flag

    // Validate input lengths
    if (strlen(sig_hex) != 130) {
        return luaL_error(L, "signature must be exactly 130 characters");
    }
    if (strlen(msg_hash_hex) != 64) {
        return luaL_error(L, "message hash must be exactly 64 characters");
    }

    // Initialize context if needed
    secp256k1_context* ctx = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY | SECP256K1_CONTEXT_SIGN);
    if (ctx == NULL) {
        return luaL_error(L, "failed to create secp256k1 context");
    }

    // Convert hex signature to bytes (excluding last byte which is recovery_id)
    unsigned char sig[64];
    for (int i = 0; i < 64; i++) {
        sscanf(&sig_hex[i * 2], "%2hhx", &sig[i]);
    }

    // Extract recovery_id from last byte of signature
    unsigned char recovery_byte;
    sscanf(&sig_hex[128], "%2hhx", &recovery_byte);
    int recovery_id = recovery_byte - 27;  // Convert from Ethereum-style encoding

    // Validate recovery_id
    if (recovery_id < 0 || recovery_id > 3) {
        return luaL_error(L, "invalid recovery id in signature (must be 27 or 28)");
    }

    // Convert hex message hash to bytes
    unsigned char msg_hash[32];
    for (int i = 0; i < 32; i++) {
        sscanf(&msg_hash_hex[i * 2], "%2hhx", &msg_hash[i]);
    }

    // Parse the signature
    secp256k1_ecdsa_recoverable_signature sig_parsed;
    if (!secp256k1_ecdsa_recoverable_signature_parse_compact(ctx, &sig_parsed, sig, recovery_id)) {
        return luaL_error(L, "failed to parse signature");
    }

    // Recover the public key
    secp256k1_pubkey pubkey;
    if (!secp256k1_ecdsa_recover(ctx, &pubkey, &sig_parsed, msg_hash)) {
        return luaL_error(L, "failed to recover public key");
    }

    // Serialize the public key in uncompressed format
    unsigned char pubkey_ser[65];
    size_t pubkey_len = sizeof(pubkey_ser);
    secp256k1_ec_pubkey_serialize(ctx, pubkey_ser, &pubkey_len, &pubkey, SECP256K1_EC_UNCOMPRESSED);

    // Convert public key to hex
    char pubkey_hex[131];  // 65 bytes * 2 + 1 for null terminator
    for (size_t i = 0; i < 65; i++) {
        sprintf(&pubkey_hex[i * 2], "%02x", pubkey_ser[i]);
    }
    pubkey_hex[130] = '\0';

    // Clean up if requested
    if (cleanup && ctx != NULL) {
        secp256k1_context_destroy(ctx);
        ctx = NULL;
    }

    // Push the result to Lua
    lua_pushstring(L, pubkey_hex);
    return 1;
}

/* Register functions */
static const struct luaL_Reg secp256k1_functions[] = {
    // lua_register(wasm_lua_state, "verify_signature", lua_verify_signature);
    // lua_register(wasm_lua_state, "recover_public_key", recover_public_key);
    {"verify_signature", lua_verify_signature},
    {"recover_public_key", recover_public_key},
    {NULL, NULL}  /* sentinel */
};

/* Module initializer function */
int luaopen_secp256k1(lua_State *L) {
    luaL_newlib(L, secp256k1_functions);
    return 1;
}

#define ROTR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define CH(x, y, z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTR(x, 2) ^ ROTR(x, 13) ^ ROTR(x, 22))
#define EP1(x) (ROTR(x, 6) ^ ROTR(x, 11) ^ ROTR(x, 25))
#define SIG0(x) (ROTR(x, 7) ^ ROTR(x, 18) ^ ((x) >> 3))
#define SIG1(x) (ROTR(x, 17) ^ ROTR(x, 19) ^ ((x) >> 10))

static const uint32_t k[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

void sha256(const unsigned char *data, size_t len, unsigned char *out) {
    uint32_t h0 = 0x6a09e667;
    uint32_t h1 = 0xbb67ae85;
    uint32_t h2 = 0x3c6ef372;
    uint32_t h3 = 0xa54ff53a;
    uint32_t h4 = 0x510e527f;
    uint32_t h5 = 0x9b05688c;
    uint32_t h6 = 0x1f83d9ab;
    uint32_t h7 = 0x5be0cd19;

    size_t chunks = ((len + 8) / 64) + 1;
    size_t total_len = chunks * 64;
    unsigned char *buf = calloc(total_len, 1);
    memcpy(buf, data, len);
    buf[len] = 0x80;
    uint64_t bits = len * 8;
    for (int i = 0; i < 8; i++) {
        buf[total_len - 8 + i] = (bits >> ((7 - i) * 8)) & 0xFF;
    }

    for (size_t chunk = 0; chunk < chunks; chunk++) {
        uint32_t w[64];
        const unsigned char *chunk_data = buf + (chunk * 64);

        for (int i = 0; i < 16; i++) {
            w[i] = (chunk_data[i * 4] << 24) |
                   (chunk_data[i * 4 + 1] << 16) |
                   (chunk_data[i * 4 + 2] << 8) |
                   (chunk_data[i * 4 + 3]);
        }

        for (int i = 16; i < 64; i++) {
            w[i] = SIG1(w[i - 2]) + w[i - 7] + SIG0(w[i - 15]) + w[i - 16];
        }

        uint32_t a = h0;
        uint32_t b = h1;
        uint32_t c = h2;
        uint32_t d = h3;
        uint32_t e = h4;
        uint32_t f = h5;
        uint32_t g = h6;
        uint32_t h = h7;

        for (int i = 0; i < 64; i++) {
            uint32_t t1 = h + EP1(e) + CH(e, f, g) + k[i] + w[i];
            uint32_t t2 = EP0(a) + MAJ(a, b, c);
            h = g;
            g = f;
            f = e;
            e = d + t1;
            d = c;
            c = b;
            b = a;
            a = t1 + t2;
        }

        h0 += a;
        h1 += b;
        h2 += c;
        h3 += d;
        h4 += e;
        h5 += f;
        h6 += g;
        h7 += h;
    }

    free(buf);

    out[0] = (h0 >> 24) & 0xFF;
    out[1] = (h0 >> 16) & 0xFF;
    out[2] = (h0 >> 8) & 0xFF;
    out[3] = h0 & 0xFF;
    out[4] = (h1 >> 24) & 0xFF;
    out[5] = (h1 >> 16) & 0xFF;
    out[6] = (h1 >> 8) & 0xFF;
    out[7] = h1 & 0xFF;
    out[8] = (h2 >> 24) & 0xFF;
    out[9] = (h2 >> 16) & 0xFF;
    out[10] = (h2 >> 8) & 0xFF;
    out[11] = h2 & 0xFF;
    out[12] = (h3 >> 24) & 0xFF;
    out[13] = (h3 >> 16) & 0xFF;
    out[14] = (h3 >> 8) & 0xFF;
    out[15] = h3 & 0xFF;
    out[16] = (h4 >> 24) & 0xFF;
    out[17] = (h4 >> 16) & 0xFF;
    out[18] = (h4 >> 8) & 0xFF;
    out[19] = h4 & 0xFF;
    out[20] = (h5 >> 24) & 0xFF;
    out[21] = (h5 >> 16) & 0xFF;
    out[22] = (h5 >> 8) & 0xFF;
    out[23] = h5 & 0xFF;
    out[24] = (h6 >> 24) & 0xFF;
    out[25] = (h6 >> 16) & 0xFF;
    out[26] = (h6 >> 8) & 0xFF;
    out[27] = h6 & 0xFF;
    out[28] = (h7 >> 24) & 0xFF;
    out[29] = (h7 >> 16) & 0xFF;
    out[30] = (h7 >> 8) & 0xFF;
    out[31] = h7 & 0xFF;
}