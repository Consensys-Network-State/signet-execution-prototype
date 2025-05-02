## Installation

Install lua and luarocks:

- `brew install lua`
- `brew install luarocks`

Install lua rocks dependencies:

`luarocks install --tree=./rocks --only-deps lua-actor-dev-1.rockspec`

## Running tests

To run a test suite making use of a C-based secp256k1 lib from within `lua-actor/src`:

`LUA_INIT=@setup.lua lua apoc-test.lua`

Install the following vscode extensions to debug Lua:

- Lua (https://marketplace.cursorapi.com/items?itemName=sumneko.lua)
- Lua Debug (https://marketplace.cursorapi.com/items?itemName=actboy168.lua-debug)

To debug the currently selected file, use the 'Debug Lua' config included in `.vscode/launch.json`.

## Development process

Philosophy:

* Develop all Lua logic locally as much as possible
* Organize our Lua code into modules when convenient

- Compile new versions of the C-based secp256k1 library and our Lua wrapper library if necessary
- Develop under test as much as possible

Writing test cases:

* Test data:
  * recreate an existing `test-data` directory, or edit an existing one
* Test scripts:
  * to begin, write or modify a script that doesn’t require wrappers, for faster iterations. See `dfsm-test.lua` vs.`dfsm-test-wrapped.lua`

Once confident enough to try changes in AO (i.e. tests are passing /w wrapped inputs):

- Use the bundle-lua.js script to bundle the lua code into a single file
  - Usage: `node bundle-lua.mjs <entry-file> [output-file]`
  - Example: `node bundle-lua.mjs src/apoc-v2.lua apoc-v2-bundled.lua`
- Upload a new AO wasm bundle to AR if secp256k1 has changed
  - update the MODULE env var with the new wasm Tx ID
- [Optional] Deployed AO actor testing:
  - Try out the new actor version by launching a new actor via AOS
  - Test it with a few manual msgs
- Update deployed AO actor with the new version
  - `cp apoc-v2-bundled.lua ../src/permaweb/ao/actors/apoc-v2-bundled.lua`
  - Manually edit `../src/permaweb/ao/actors/apoc-v2-bundled.lua` and remove the indicated lines at the top of the file.
- Update alpha env, env-to-end testing
  - Run requests against API to test

## Legacy libs

To run a test suite for the lua-only library (no longer used by our actor code) from within `lua-actor/src`:

`LUA_INIT=@setup.lua lua es256k-test.lua`

I'm including it and the test suite here for posterity, and since its public interface is slightly different (JWT and signature validation VS VC validation). Most of the logic however is implementing the base EC signature validation, which is slower than using the wrapped C lib.
