-- src/setup.lua
local version = _VERSION:match("%d+%.%d+")

package.path = 'rocks/lib/lua/' .. version ..
    '/?.lua;rocks/lib/lua/' .. version ..
    '/?/init.lua;' .. package.path
package.cpath = 'rocks/lib/lua/' .. version ..
    '/?.so;' .. package.cpath