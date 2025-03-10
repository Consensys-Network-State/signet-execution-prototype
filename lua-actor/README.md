Install the following vscode extensions:
- Lua
- Lua Debug

Install lua and lua rocks:
`brew install lua@5.3`
`brew install luarocks`

Install lua lib depends:
`luarocks install --tree=./rocks --only-deps lua-actor-dev-1.rockspec`



To run the test suite command-line from within `lua-actor/src`:
`LUA_INIT=@setup.lua lua test.lua`

To debug the currently active file, use the 'Debug Lua' config included in `.vscode/launch.json`.