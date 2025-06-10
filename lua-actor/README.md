## Installation

Install lua and luarocks:

- `brew install lua`
- `brew install luarocks`

Install lua rocks dependencies:

`luarocks install --tree=./rocks --only-deps lua-actor-dev-1.rockspec`

## Running tests

To run a test suite for an end-to-end of an agreement with VC inputs:

`LUA_INIT=@setup.lua lua dfsm-test-wrapped.lua`

Note that an [augmented Veramo library](https://github.com/Consensys-Network-State/signet-veramo) is used to generate verifiable credentials.

To run a test suite for an end-to-end of an agreement without the VC requirements:

`LUA_INIT=@setup.lua lua dfsm-test-wrapped.lua`

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

* To run all test suites (from within `./lua-actor/src`):
```
./run-tests.sh
```
* Adding new test data:
  * recreate an existing `test-data` directory, or edit an existing one
* Adding new test suites:
  * to begin, write or modify a script that doesn’t require wrappers, for faster iterations. See `dfsm.test.lua` vs.`dfsm-wrapped.test.lua`
  * make sure to name the files `*.test.lua` in order for them to be picked up by our test runner script

Once confident enough to try changes in AO (i.e. tests are passing /w wrapped inputs):

- Rebuild default bundle: `./rebuild_bundle.sh` (from within `./lua-actor/src`)

- To build a specific bundle, you can use the bundle-lua.js script to bundle the lua code into a single file (run from the `/lua-actor` directory)
  - Usage: `node bundle-lua.mjs <entry-file> [output-file]`
  - Example: `node bundle-lua.mjs src/apoc-v2.lua src/apoc-v2-bundled.lua`
  
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

## AO Deployment Scripts

Two scripts are provided for deploying and initializing agreements on the AO network:

### Prerequisites

Make sure you have a `.env` file in the project root with the following variables:
```
WALLET_JSON_FILE=~/.aos.json
MODULE=NjanQA2OVxGTWbfTk-JpqCMscG2J9l4Vaq8sqeBKUm8
SCHEDULER=_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA
MU=fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY%
```

### deploy-lua.mjs

Deploys a Lua bundle to the AO network, creating a new process.

**Usage:** `node deploy-lua.mjs <bundle-path>`

**Example:**
```bash
node deploy-lua.mjs src/apoc-v2-bundled.lua
```

This will:
- Load your wallet from the environment configuration
- Create a new AO process 
- Clean the bundle for AO compatibility (removes problematic lines)
- Deploy the cleaned Lua code to the process
- Return a process ID for initialization

**⚠️ Warning:** This operation costs real AR tokens!

### initialize-agreement.mjs

Initializes a deployed AO process with agreement data using a Verifiable Credential.

**Usage:** `node initialize-agreement.mjs <process-id> <json-file-path>`

**Example:**
```bash
node initialize-agreement.mjs z1SePKeaiSogO8lZL8oAh4M9pQLjzp3k6LE9rJriqgs src/tests/manifesto/wrapped/manifesto.wrapped.json
```

This will:
- Load the agreement VC from the specified JSON file
- Send an "Init" action to the deployed process
- Validate the initialization was successful
- Provide next steps for testing

**⚠️ Warning:** This operation costs real AR tokens!

### Complete Deployment Example

Here's a complete workflow from deployment to initialization:

1. **Deploy the bundle:**
   ```bash
   node deploy-lua.mjs src/apoc-v2-bundled.lua
   ```
   
   Expected output:
   ```
   🎉 Deployment complete! Process ID: z1SePKeaiSogO8lZL8oAh4M9pQLjzp3k6LE9rJriqgs
   ```

2. **Initialize with agreement data:**
   ```bash
   node initialize-agreement.mjs z1SePKeaiSogO8lZL8oAh4M9pQLjzp3k6LE9rJriqgs src/tests/manifesto/wrapped/manifesto.wrapped.json
   ```
   
   Expected output:
   ```
   ✅ Agreement successfully initialized
   🎉 Initialization Summary:
      Process ID: z1SePKeaiSogO8lZL8oAh4M9pQLjzp3k6LE9rJriqgs
      Success: true
   ```

3. **Test your deployment:**
   ```bash
   aos z1SePKeaiSogO8lZL8oAh4M9pQLjzp3k6LE9rJriqgs
   ```
   
   Then in the AOS console:
   ```lua
   Send({ Target = "z1SePKeaiSogO8lZL8oAh4M9pQLjzp3k6LE9rJriqgs", Action = "GetState" })
   ```

Both scripts include comprehensive error handling, cost warnings, and help functionality (`--help` flag).

## Legacy libs

To run a test suite for the lua-only library (no longer used by our actor code) from within `lua-actor/src`:

`LUA_INIT=@setup.lua lua es256k-test.lua`

I'm including it and the test suite here for posterity, and since its public interface is slightly different (JWT and signature validation VS VC validation). Most of the logic however is implementing the base EC signature validation, which is slower than using the wrapped C lib.