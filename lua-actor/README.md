Install the following vscode extensions:
- Lua
- Lua Debug

Install lua and lua rocks:
`brew install lua`
`brew install luarocks`

Install lua lib depends:
`luarocks install --tree=./rocks --only-deps lua-actor-dev-1.rockspec`

To run a test suite of lua-only library from within `lua-actor/src`:
`LUA_INIT=@setup.lua lua test.lua`

To run a test making use of a C-based secp256k1 lib from within `lua-actor/src`:
`LUA_INIT=@setup.lua lua apoc-test.lua`

To debug the currently active file, use the 'Debug Lua' config included in `.vscode/launch.json`.