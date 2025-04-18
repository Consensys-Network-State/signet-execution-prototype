First off, you don't need to build anything in this project - I've checked ina Lua-wrapped version of the secp256k1 library.

To use it, you can just require it in your Lua scripts like so (provided that you've required the `setup.lua` file first. See `lua-actor/README.md` for more info):
```
local secp256k1 = require("secp256k1")
```

The two lib functions currently exposed to Lua are:
- `verify_signature(message, signature, pubkey)`: verifies a signature against a message and a public key
- `recover_public_key(signature, message_hash)`: recovers a public key from a signature and a message hash

See `test_secp256k1.lua` for usage examples.


If we ever need to recompile the Lua-wrapped version of the secp256k1 library, here are the steps I took to do so:

First, compile a static version of the secp256k1 library.
Clone it locally from: https://github.com/bitcoin-core/secp256k1 (I checked out the latest stable tag - `v0.6.0`)

Follow their automake steps to get the lib built:
1. `brew install automake` (this is needed by their configure script)
2. (may be needed, install if you get errors with the next step)`brew install cmake`
2. `./configure --enable-module-recovery` (enabling the optional public key recovery module)
3. `make`

Should now have a `libsecp256k1.a` file under `.libs/` in your local secp256k1 clone.

Copy `libsecp256k1.a` into `./lua-actor/src/secp256k1-lua/` and run `make` to build our Lua-wrapper version of the lib.

There should now be a `secp256k1.so` file generated, which can be 'required' directly in Lua scripts as if it were a Lua library:
```
local secp256k1 = require("secp256k1")
```

Run some tests to make sure it's working:
```
lua test_secp256k1.lua
```








