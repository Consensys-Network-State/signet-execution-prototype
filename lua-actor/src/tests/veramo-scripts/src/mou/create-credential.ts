import { agent } from '../veramo/setup.js'
import fs, { readFileSync, writeFileSync } from 'fs'
import { join } from 'path'
import { fileURLToPath } from 'url'
import { ethers } from 'ethers'

const testDir = '../../../'
const inputDir = fileURLToPath(new URL(`${testDir}/mou/unwrapped`, import.meta.url))
const outputDir = fileURLToPath(new URL(`${testDir}/mou/wrapped`, import.meta.url))
if (!fs.existsSync(outputDir)){
  fs.mkdirSync(outputDir);
}
const agreement = JSON.parse(readFileSync(join(inputDir, 'mou.json'), 'utf-8'));
const partyAInput = JSON.parse(readFileSync(join(inputDir, 'input-partyA.json'), 'utf-8'));
const partyBInput = JSON.parse(readFileSync(join(inputDir, 'input-partyB.json'), 'utf-8'));
const partyAAcceptInput = JSON.parse(readFileSync(join(inputDir, 'input-partyA-accept.json'), 'utf-8'));
const partyARejectInput = JSON.parse(readFileSync(join(inputDir, 'input-partyA-reject.json'), 'utf-8'));

async function writeVc(params, name) {
  const vc = await agent.createVerifiableCredential(params);
  const isValid = await agent.verifyCredential({ credential: vc })
  if (!isValid) {
    throw new Error(`Generated an invalidl VC given params: ${JSON.stringify(params)}`);
  }
  const filename = `${name}.wrapped.json`;
  const vcStr = JSON.stringify(vc, null, 2);
  writeFileSync(join(outputDir, filename), vcStr);
  console.log(`Saved VC to ./${outputDir}/${filename}`);
  return { vc, vcStr, filename };
}

const didStrToEthAddress = didStr => didStr.slice(didStr.lastIndexOf(":") + 1);

async function main() {
  const agreementCreator = await agent.didManagerGetByAlias({ alias: 'partyC' })
  const partyA = await agent.didManagerGetByAlias({ alias: 'partyA' })
  const partyB = await agent.didManagerGetByAlias({ alias: 'partyB' })
  const partyAEthAddress = didStrToEthAddress(partyA.did);
  const partyBEthAddress = didStrToEthAddress(partyB.did);

  try {
    const agreementParams = {
      credential: {
        issuer: { id: agreementCreator.did },
        credentialSubject: {
          id: "did:example:mou-recipient-1",
          agreement: Buffer.from(JSON.stringify(agreement)).toString('base64'),
          params: {
            partyAEthAddress,
            partyBEthAddress,
          }
        },
        type: ['VerifiableCredential','AgreementCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    const { vcStr: agreementDocStr } = await writeVc(agreementParams, `mou`);
    const agreementDocHash = ethers.keccak256(new TextEncoder().encode(agreementDocStr));

    partyAInput.documentHash = agreementDocHash;
    partyBInput.documentHash = agreementDocHash;
    partyAAcceptInput.documentHash = agreementDocHash;
    partyARejectInput.documentHash = agreementDocHash;

    partyAInput.values.partyBEthAddress = partyBEthAddress;
    const partyAInputParams = {
      credential: {
        issuer: { id: partyA.did },
        credentialSubject: partyAInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(partyAInputParams, `input-partyA`);

    const partyBInputParams = {
      credential: {
        issuer: { id: partyB.did },
        credentialSubject: partyBInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(partyBInputParams, `input-partyB`);

    const partyAAcceptParams = {
      credential: {
        issuer: { id: partyA.did },
        credentialSubject: partyAAcceptInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(partyAAcceptParams, `input-partyA-accept`);

    const partyARejectParams = {
      credential: {
        issuer: { id: partyA.did },
        credentialSubject: partyARejectInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(partyARejectParams, `input-partyA-reject`);
  } catch(e) {
    console.error("Error", e)
  }
}

main().catch(console.log) 