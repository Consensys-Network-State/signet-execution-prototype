-- Utility functions for testing Lua AO Actors

-- Print a table recursively with nice formatting
local function printTable(t, indent)
  indent = indent or ""
  for k, v in pairs(t) do
    if type(v) == "table" then
      print(indent .. tostring(k) .. " = {")
      printTable(v, indent .. "  ")
      print(indent .. "}")
    else
      print(indent .. tostring(k) .. " = " .. tostring(v))
    end
  end
end

-- Compare two tables recursively by value
local function tablesEqual(t1, t2)
  -- If either isn't a table, compare directly
  if type(t1) ~= "table" or type(t2) ~= "table" then
    return t1 == t2
  end
  
  -- Check if all keys in t1 exist with same value in t2
  for k, v in pairs(t1) do
    if not tablesEqual(v, t2[k]) then
      return false
    end
  end
  
  -- Check if all keys in t2 exist in t1 (to catch extra keys in t2)
  for k in pairs(t2) do
    if t1[k] == nil then
      return false
    end
  end
  
  return true
end

-- Format boolean test results with colored output
local function formatResult(bool)
  if bool then
    return '\x1b[6;30;42m'..'SUCCESS'..'\x1b[0m'
  else
    return '\x1b[0;30;41m'..'FAILURE'..'\x1b[0m'
  end
end

-- Log a successful test with a checkmark
local function logTest(message, testCounter)
  if testCounter then
    testCounter.count = testCounter.count + 1
  end
  print("✅ PASSED: " .. message)
end

-- Export the utility functions
return {
  printTable = printTable,
  tablesEqual = tablesEqual,
  formatResult = formatResult,
  logTest = logTest
}

