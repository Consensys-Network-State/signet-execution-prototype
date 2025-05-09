-- Find all *.test.lua files using the 'find' shell command
local test_files = {}
for file in io.popen('find . -name "*.test.lua"'):lines() do
    table.insert(test_files, file)
end

table.sort(test_files)  -- Sort test files alphabetically

local failed_suites = {}
local total = 0
local failed = 0

for _, file in ipairs(test_files) do
    print("\n=== Running test suite: " .. file .. " ===")
    -- Save the original print function
    local original_print = print
    -- Override print to do nothing
    print = function() end

    local ok, err = pcall(function() dofile(file) end)

    -- Restore the original print function
    print = original_print

    total = total + 1
    if ok then
        print("✅ Suite PASSED: " .. file)
    else
        print("❌ Suite FAILED: " .. file)
        print("  Error: " .. tostring(err))
        failed = failed + 1
        table.insert(failed_suites, {file=file, error=err})
    end
end

print("\n=====================================")
print("Test suites run: " .. total)
print("Suites failed: " .. failed)
if #failed_suites > 0 then
    print("Failed suites:")
    for _, f in ipairs(failed_suites) do
        print("  " .. f.file)
        print("    Error: " .. tostring(f.error))
    end
else
    print("All test suites passed!")
end
print("=====================================") 