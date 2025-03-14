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
Our Lua actor code development process will likely look like the following:
- Develop all Lua logic locally as much as possible
  - Organize our Lua code into modules when convenient
  - Compile new versions of the C-based secp256k1 library and our Lua wrapper library if necessary
  - Develop under test as much as possible
- When we're confident enough to try our changes in AO, we:
  - Inline all library and etc logic into a single lua file
  - Add message-handling logic ('Handlers.add' etc)
  - Fix any import statement discrepancies between the dev env and AO env (should be minimal)
  - Upload a new AO wasm bundle to AR if secp256k1 has changed
    - update the MODULE env var with the new wasm Tx ID
  - Try out the new actor version by launching a new actor via AOS? Test it with a few manual msgs?
  - Update `./src/permaweb/ao/actors/apoc.lua` with the new version
  - Update alpha env, env-to-end testing



## Legacy libs
To run a test suite for the lua-only library (no longer used by our actor code) from within `lua-actor/src`:

`LUA_INIT=@setup.lua lua es256k-test.lua`

I'm including it and the test suite here for posterity, and since its public interface is slightly different (JWT and signature validation VS VC validation). Most of the logic however is implementing the base EC signature validation, which is slower than using the wrapped C lib.