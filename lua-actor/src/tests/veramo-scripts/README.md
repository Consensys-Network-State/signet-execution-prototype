### Purpose
This little repo aims to assist with the setup of a local Veramo agent in order to be able to easily generate samples of well-formed VCs. Veramo libs are doing all of the heavy lifting in terms of supporting different DID methods and VC signature types.
The project was setup by mostly following this [Veramo guide](https://veramo.io/docs/node_tutorials/node_setup_identifiers/)

### Setup instructions
Use node v20+

Install deps and apply our patches:

`npm install`
`pnpm patch-package --patch-dir=patches`

Install the Veramo cli in order to be able to do some things easily, and without writing custom scripts:

`npm -g i @veramo/cli`

Generate an encryption key for Veramo to use internally (note the hex value in the output):

`npx @veramo/cli config create-secret-key`

Create a `.env` file, and supply the following values:
```
KMS_SECRET_KEY=<the hex value above>
INFURA_PROJECT_ID=<our infura projectID>
```

Create the default identity for Veramo agent to use when generating credentials:

`npx tsx ./src/create-identifier.ts`

You can create additional identities in order to have multiple credential issuance personas:

```
npx tsx ./src/create-identifier.ts partyA
npx tsx ./src/create-identifier.ts partyB
npx tsx ./src/create-identifier.ts partyC
```

You can list the currently-defined identities like this:

`npx tsx ./src/list-identifiers.ts`

### How to generate VCs
To learn how to create VCs, take a look at this script:

`npx tsx ./src/create-credential.ts`

The more up-to-date script that tries to generate the MOA agreement VC, plus the downstream input VCs is here::

`npx tsx ./src/moa-agreement/create-credential.ts`

We'll likely want to keep expanding the library of VC generation scripts to cover the scenarios we care about. For example, we might want to have a script that takes a specific agreement doc, and generates a VC-wrapped version of it, as well as a complete set of VCs representing inputs from agreement participants.

### Veramo library patches
There are a few npm library patches we have checked in (under `./patches`) and should be auto-applies during installation:
- `@veramo/credential-eip712` - adding the ability to explicitly passing EIP-712 model definitions when creating a VC. The default behaviour is to try to auto-generate it based on the credentialSubject data shape, but the vanilla version of the library `eip-712-types-generation` used for this cannot handle non-primitive array types.
- `eip-712-types-generation` - fixing some bugs + attempting to add support for non-primitive array types during EIP-712 model auto-generation logic. Mainly doing this because their algo is almost there, and would help us to not have to hand-roll these model definitions ourselves. With this patch in place, we have a better shot at auto-genning new versions of the model as our schema changes.