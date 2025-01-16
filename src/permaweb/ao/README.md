TODO: the current actor implementation expects just the JWT proof part of the VC document. Need to update it to work with full VC docs

Example procedure creating a document actor and interacting with it manually via aos:

1. Start a new actor via aos (pick a name for it, eg. `apoc`):

`aos apoc --module=NjanQA2OVxGTWbfTk-JpqCMscG2J9l4Vaq8sqeBKUm8 --load ./actors/apoc.lua`

2. Send `Init` message containing the agreement document:

`Send({ Target='jDxFAW7eOvJNdUE-mc1R5udAEtpqEVUEFSL3bjYY88M', Action='Init', Data='<agreement vc>' })`

3. Send `Sign` message to add a signature:

`Send({ Target='jDxFAW7eOvJNdUE-mc1R5udAEtpqEVUEFSL3bjYY88M', Action='Sign', Data='<signature vc>' })`

4. [Optional] Examine the internal actor state via `GetState` message:

`Send({ Target='jDxFAW7eOvJNdUE-mc1R5udAEtpqEVUEFSL3bjYY88M', Action='GetState' })`

5. [if you ever need to load a modified version via `aos`]

`.load ./actors/apoc.lua`
