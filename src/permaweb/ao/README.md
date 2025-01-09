TODO: the current actor implementation expects just the JWT proof part of the VC document. Need to update it to work with full VC docs

Example procedure creating a document actor and interacting with it manually via aos:

1. Start a new actor via aos:

`aos apoc --module=IlqppmLdIBssZtmY5TlPwTzFUZLkDEhT7aaqoyCrw3A`

2. Load up actor code:

`.load ./actors/apoc.lua`

3. Send `Init` message containing the agreement document:

`Send({ Target='blVSl6Zo_Mahqhqnt41JLT1efW-ihzMsk6ITvNX57OQ', Action='Initialize', Data='eyJhbGciOiJFUzI1NksiLCJ0eXAiOiJKV1QifQ.eyJ2YyI6eyJAY29udGV4dCI6WyJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIl0sImNyZWRlbnRpYWxTdWJqZWN0Ijp7ImFncmVlIjoidG8gZGlzYWdyZWUiLCJmb28iOiJiYXIiLCJzaWduYXRvcmllcyI6WyIweDJhNmZmYjUzNDFmOGMxY2UxMjMzNDMxNjJlMzM1MWYxYjYyODZjNDMiXX19LCJuYmYiOjE3MzY0NDQ1NTQsImlzcyI6ImRpZDpldGhyOnNlcG9saWE6MHgwMmM2M2VmZTNkYzcwN2Y2ZTNkMzIzZjExZTQwY2YwNzU3OGIyYWI5YWVlMTYzNWU2ZWU2NzZmNmRhMDlmMTU5OGQifQ.VEHlsQ7rF5Z5lDuQPZjSp2Tsd-QM0tSB5SWBmE_jZpo3xk7B9O1Wd50Smi9FVEbc4cIvi502yptcUeGwqiUO_A' })`

4. Send `Sign` message to add a signature:

`Send({ Target='blVSl6Zo_Mahqhqnt41JLT1efW-ihzMsk6ITvNX57OQ', Action='Sign', Data='eyJhbGciOiJFUzI1NksiLCJ0eXAiOiJKV1QifQ.eyJ2YyI6eyJAY29udGV4dCI6WyJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIl0sImNyZWRlbnRpYWxTdWJqZWN0Ijp7ImRvY3VtZW50SGFzaCI6ImZvb2JhcmJheiJ9fSwibmJmIjoxNzM2NDQ1MTMyLCJpc3MiOiJkaWQ6ZXRocjpzZXBvbGlhOjB4MDJjNjNlZmUzZGM3MDdmNmUzZDMyM2YxMWU0MGNmMDc1NzhiMmFiOWFlZTE2MzVlNmVlNjc2ZjZkYTA5ZjE1OThkIn0.VEHlsQ7rF5Z5lDuQPZjSp2Tsd-QM0tSB5SWBmE_jZppBEyHyrlETnnE4r6x4blXfg1Jrrf8NzvdLs6EnFONfjA' })`

5. [Optional] Examine the internal actor state via `GetState` message:

`Send({ Target='blVSl6Zo_Mahqhqnt41JLT1efW-ihzMsk6ITvNX57OQ', Action='GetState' })`

