-- src/setup.lua
local version = _VERSION:match("%d+%.%d+")

function get_script_path()
  local debug = require("debug")
  local info = debug.getinfo(1, "S")
  local source = info.source:sub(2)  -- Remove @ prefix
  
  -- If it seems like a relative path, try to make it absolute
  if not source:match("^[/\\]") and not source:match("^%a:[/\\]") then
      -- Use io.popen to get current directory (works on most systems)
      local handle = io.popen("pwd 2>/dev/null || cd")
      local result = handle:read("*a"):gsub("\n$", "")
      handle:close()
      
      source = result .. "/" .. source
  end
  
  return source
end

function get_parent_dir()
  local script_path = get_script_path()
  local script_dir = script_path:match("(.*/)")
  if script_dir:sub(-1) == "/" then
    script_dir = script_dir:sub(1, -2)
  end
  -- print("Script dir:", script_dir)
  local parent_dir = script_dir:match("(.+)[/\\][^/\\]*$")
  -- print("Parent path:", parent_dir)
  return parent_dir
end

-- finding the parent dir relative to this file, then adding the required path values to include libraries
-- locally installed via luarocks. Also making stuff under `src/ao-libs` available.
local parent_dir = get_parent_dir()

package.path =
  -- this part allows libraries installed via luarocks to be resolved at runtime. Currently only bit32 lib is installed this way to
  -- make one of the AO libs happy.
  parent_dir .. '/rocks/lib/lua/' .. version .. '/?.lua;' ..
  parent_dir .. '/rocks/lib/lua/' .. version .. '/?/init.lua;'..
  -- this part allows requiring the libraries available inside of the AO execution environment via matching paths
  parent_dir .. '/src/ao-libs/?.lua;' ..
  parent_dir .. '/src/ao-libs/?/init.lua;' ..
  package.path
package.cpath =
  parent_dir .. '/rocks/lib/lua/' .. version .. '/?.so;' .. -- C libs installed via luarocks
  -- this part allows requiring 'secp256k1' without additional pathing
  parent_dir .. '/src/secp256k1-lua/?.so;' ..
  package.cpath