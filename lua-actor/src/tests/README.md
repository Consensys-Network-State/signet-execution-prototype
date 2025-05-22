# Instructions

Initialize the submodule `sobol-veramo` first, then follow the instructions to install the prerequisites in that repo (https://github.com/ConsenSysMesh/sobol-veramo).

In particular, make sure to create a `.env` file with a secret key inside this directory.

# 🤖✅ Vibe Coding Tests ✅🤖

If your goal is to create an agreement with a full test suite, [like this](./grant-with-feedback/grant-with-feedback.md), you can follow these steps to generate your own using AI assistance.

1. Create an input DFSM you would like to use, using one of the existing templates, like [this sample agreement with feedback](./grant-with-feedback/unwrapped/grant-with-feedback.json). Iterate on this JSON file until the right DFSM is created. It is recommended that you create a corresponding md file to visually describe the state machine. You could even start with the diagram first. See [this corresponding md file](./grant-with-feedback/grant-with-feedback.md).

**Sample prompt:**

```
Given @grant-with-feedback.json as reference, I'd like you to create a new agreement, describing the following flow <insert your flow here>. Generate all the necessary state transitions for this, as well as the corresponding inputs.

Alongside this, generate an md file containing a mermain diagram describing the DFSM we are using for this agreement. Use @grant-with-feedback.md for reference (see the 1st diagram.)
```

2. You will need to generate corresponding input files to provide to the state machine. For faster iteration, use non-VC-wrapped inputs. Wrapping inputs involves cryptographic signing with identities so we want to avoid that until we are more confident in the overall test flow. You can use [sample inputs like here](./grant-with-feedback/unwrapped) for a starting point.

**Sample prompt:**

```
Now generate the corresponding input files to drive this state machine forward. Generate input JSON files, exactly like is done here @unwrapped (directory context). See @grant-with-feedback.test.lua for reference on how these inputs will be used in the future.
```

3. Once you have the inputs to the fidelity you would like, you can try starting a skeleton of a test suite for your agreement. Again, start with a starting point like [this LUA test suite](./grant-with-feedback/grant-with-feedback.test.lua). You should disable the wrapped version of the tests while getting it up and running.

**Sample prompt:**

```
Now generate a file exactly like @grant-with-feedback.test.lua, but disable the wrapped path testing for now, and only focus on unwrapped inputs. The file should test the happy path to start only.

Your goal is for this command to start working: [~/src/signet-execution-prototype/lua-actor/src]$ LUA_INIT=@setup.lua lua run-tests.lua.
```

4. You are ready to start incrementing on your overall agreement while actually testing now. You need to instruct the AI to run tests every step of the way. To do so, give it explicit instructions on what command to run, including the working directory.

**Sample prompt:**

```
@grant-with-feedback.test.lua now I'd like you to augment the test case here. you have modelled a single work submission and review scenario. I'd like you to change this to involve two submissions for review instead. you may need to generate another input unwrapped json document. once you've got the unwrapped portion working, you can use the following to generate wrapped version of all the inputs:

[~/src/signet-execution-prototype/lua-actor/src/tests/veramo-scripts]$ npx tsx ./src/grant-with-feedback/create-credential.ts

always use the following periodically to see if our tests are passing:

[~/src/signet-execution-prototype/lua-actor/src]$ LUA_INIT=@setup.lua lua run-tests.lua
```

Once you get a green ✅ on all tests, you are on your way to making more complicated cases.

5. Once you get the happy path test suites running, you are now free to iterate on your flow and also test "unhappy" paths.

**Sample prompt:**

```
Now add the failure scenario where the other party denies the request. Add this case to the test file. Add the corresponding json input. As always, first test the unwrapped case, run the tests, then run the command I showed you to generate the wrapped inputs, and run the tests again. Every major change you make, run the tests to be sure it works.
```
