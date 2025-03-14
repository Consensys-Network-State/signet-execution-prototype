Install the following vscode extensions:
- Lua
- Lua Debug

Install lua and lua rocks:
`brew install lua`
`brew install luarocks`

Install lua lib depends:
`luarocks install --tree=./rocks --only-deps lua-actor-dev-1.rockspec`

To run a test making use of a C-based secp256k1 lib from within `lua-actor/src`:
`LUA_INIT=@setup.lua lua apoc-test.lua`

To debug the currently active file, use the 'Debug Lua' config included in `.vscode/launch.json`.

To run a test suite for the lua-only library (no longer used by our actor code) from within `lua-actor/src`:
`LUA_INIT=@setup.lua lua es256k-test.lua`
I'm including it and the test suite here for posterity, and since its public interface is slightly different (JWT and signature validation VS VC validation). Most of the logic however is implementing the base EC signature validation, which is slower than using the wrapped C lib.