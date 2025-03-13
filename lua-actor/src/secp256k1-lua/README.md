To build the Lua-wrapped module, I had to first build a static version of the secp256k1 library.
Clone it locally: https://github.com/bitcoin-core/secp256k1

I followed their automake steps to get the lib built:
1. `brew install automake` (this is needed by their configure script)
2. (maybe needed?)`brew install cmake`
2. `./configure --enable-module-recovery` (enabling the optional public key recovery module)
3. `make`

Should now have a `libsecp256k1.a` file under `.libs/`

Copy `libsecp256k1.a` into this dir and run `make` to build our Lua-wrapper version of the lib.

There should now be a `secp256k1.so` file generated, which can be 'required' in Lua programs like so:
```
local secp256k1 = require("secp256k1")
```

If all is well, you can try to run the test script like so:
```
lua test_secp256k1.lua
```








