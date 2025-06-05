import { agent } from '../veramo/setup.js'
import fs, { readFileSync, writeFileSync } from 'fs'
import { join } from 'path'
import { fileURLToPath } from 'url'
import { ethers } from 'ethers'

const testDir = '../../../'
const inputDirname = fileURLToPath(new URL(`${testDir}/manifesto/unwrapped`, import.meta.url))
const outputDir = fileURLToPath(new URL(`${testDir}/manifesto/wrapped`, import.meta.url))
if (!fs.existsSync(outputDir)){
  fs.mkdirSync(outputDir);
}
const agreement = JSON.parse(readFileSync(join(inputDirname, 'manifesto.json'), 'utf-8'));
const aliceSignatureInput = JSON.parse(readFileSync(join(inputDirname, 'input-alice-signature.json'), 'utf-8'));
const bobSignatureInput = JSON.parse(readFileSync(join(inputDirname, 'input-bob-signature.json'), 'utf-8'));

async function writeVc(params, name) {
  const vc = await agent.createVerifiableCredential(params);
  const isValid = await agent.verifyCredential({ credential: vc })
  if (!isValid) {
    throw new Error(`Generated an invalid VC given params: ${JSON.stringify(params)}`);
  }
  // Use consistent naming with unwrapped version, just add .wrapped suffix
  const filename = `${name}.wrapped.json`;
  const vcStr = JSON.stringify(vc, null, 2);
  writeFileSync(join(outputDir, filename), vcStr);
  console.log(`Saved VC to ./${outputDir}/${filename}`);
  return { vc, vcStr, filename };
}

const didStrToEthAddress = didStr => didStr.slice(didStr.lastIndexOf(":") + 1);

async function main() {
  const manifestoController = await agent.didManagerGetByAlias({ alias: 'partyC' })
  const alice = await agent.didManagerGetByAlias({ alias: 'partyA' })
  const bob = await agent.didManagerGetByAlias({ alias: 'partyB' })
  const controllerEthAddress = didStrToEthAddress(manifestoController.did);
  const aliceEthAddress = didStrToEthAddress(alice.did);
  const bobEthAddress = didStrToEthAddress(bob.did);

  try {
    // Create wrapped manifesto agreement
    const agreementParams = {
      credential: {
        issuer: { id: manifestoController.did },
        credentialSubject: {
          id: "did:example:manifesto-1",
          agreement: Buffer.from(JSON.stringify(agreement)).toString('base64'),
          params: {
            controller: controllerEthAddress
          }
        },
        type: ['VerifiableCredential','AgreementCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    const { vcStr } = await writeVc(agreementParams, `manifesto`);
    const agreementDocHash = ethers.keccak256(new TextEncoder().encode(vcStr));

    // Set the documentHash for all input VCs
    aliceSignatureInput.documentHash = agreementDocHash;
    bobSignatureInput.documentHash = agreementDocHash;
    
    // Update signature addresses to match the actual signer addresses
    aliceSignatureInput.values.signerAddress = aliceEthAddress;
    bobSignatureInput.values.signerAddress = bobEthAddress;

    // Create Alice's signature VC
    const aliceSignatureParams = {
      credential: {
        issuer: { id: alice.did },
        credentialSubject: aliceSignatureInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(aliceSignatureParams, `input-alice-signature`);

    // Create Bob's signature VC
    const bobSignatureParams = {
      credential: {
        issuer: { id: bob.did },
        credentialSubject: bobSignatureInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(bobSignatureParams, `input-bob-signature`);

    // Create activate input VC (controller action)
    const activateInputParams = {
      credential: {
        issuer: { id: manifestoController.did },
        credentialSubject: {
          inputId: "activate",
          type: "signedFields",
          documentHash: agreementDocHash,
          values: {
            activation: "ACTIVATE"
          }
        },
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(activateInputParams, `input-activate`);

    // Create deactivate input VC (controller action)
    const deactivateInputParams = {
      credential: {
        issuer: { id: manifestoController.did },
        credentialSubject: {
          inputId: "deactivate",
          type: "signedFields",
          documentHash: agreementDocHash,
          values: {
            activation: "DEACTIVATE"
          }
        },
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(deactivateInputParams, `input-deactivate`);

  } catch(e) {
    console.error("Error", e)
  }
}

main().catch(console.log) 