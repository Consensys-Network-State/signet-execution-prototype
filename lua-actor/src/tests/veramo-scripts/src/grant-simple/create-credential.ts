import { agent } from '../veramo/setup.js'
import fs, { readFileSync, writeFileSync } from 'fs'
import { join } from 'path'
import { fileURLToPath } from 'url'
import { getTransactionProofData } from '../fetch-tx-proof.js'
import { ethers } from 'ethers'

const testDir = '../../../'
const inputDirname = fileURLToPath(new URL(`${testDir}/grant-simple/unwrapped`, import.meta.url))
const outputDir = fileURLToPath(new URL(`${testDir}/grant-simple/wrapped`, import.meta.url))
if (!fs.existsSync(outputDir)){
  fs.mkdirSync(outputDir);
}
const agreement = JSON.parse(readFileSync(join(inputDirname, 'grant-simple.json'), 'utf-8'));
const grantorInput = JSON.parse(readFileSync(join(inputDirname, 'input-grantor.json'), 'utf-8'));
const recipientInput = JSON.parse(readFileSync(join(inputDirname, 'input-recipient.json'), 'utf-8'));
const grantorAcceptInput = JSON.parse(readFileSync(join(inputDirname, 'input-grantor-accept.json'), 'utf-8'));
const grantorRejectInput = JSON.parse(readFileSync(join(inputDirname, 'input-grantor-reject.json'), 'utf-8'));
const workSubmissionInput = JSON.parse(readFileSync(join(inputDirname, 'input-work-submission.json'), 'utf-8'));
const workAcceptInput = JSON.parse(readFileSync(join(inputDirname, 'input-work-accept.json'), 'utf-8'));
const workRejectInput = JSON.parse(readFileSync(join(inputDirname, 'input-work-reject.json'), 'utf-8'));
const agreementRejectInput = JSON.parse(readFileSync(join(inputDirname, 'input-agreement-reject.json'), 'utf-8'));
const txHash = "0x15cdc2d5157685faaca3da6928fe412608747e76a7daee0800d5c79c2b76a0cd";

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
  const agreementCreator = await agent.didManagerGetByAlias({ alias: 'partyC' })
  const grantor = await agent.didManagerGetByAlias({ alias: 'partyA' })
  const recipient = await agent.didManagerGetByAlias({ alias: 'partyB' })
  const grantorEthAddress = didStrToEthAddress(grantor.did);
  const recipientEthAddress = didStrToEthAddress(recipient.did);
  const proofDataStr = await getTransactionProofData(txHash, 59141);
  const proofDataBase64 = btoa(proofDataStr!);

  try {
    // Use consistent naming with unwrapped version
    const agreementParams = {
      credential: {
        issuer: { id: agreementCreator.did },
        credentialSubject: {
          id: "did:example:grant-simple-recipient-1",
          agreement: Buffer.from(JSON.stringify(agreement)).toString('base64'),
          params: {
            grantorEthAddress: grantorEthAddress,
            recipientEthAddress: recipientEthAddress
          }
        },
        type: ['VerifiableCredential','AgreementCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    const { vcStr } = await writeVc(agreementParams, `grant-simple`);
    const agreementDocHash = ethers.keccak256(new TextEncoder().encode(vcStr));

    // Set the documentHash for all input VCs
    grantorInput.documentHash = agreementDocHash;
    recipientInput.documentHash = agreementDocHash;
    grantorAcceptInput.documentHash = agreementDocHash;
    grantorRejectInput.documentHash = agreementDocHash;
    workSubmissionInput.documentHash = agreementDocHash;
    workAcceptInput.documentHash = agreementDocHash;
    workRejectInput.documentHash = agreementDocHash;
    agreementRejectInput.documentHash = agreementDocHash;
    
    // making sure that we're referencing the right Eth address regardless of whose Veramo agent the script is running on
    grantorInput.values.recipientEthAddress = recipientEthAddress;
    const grantorInputParams = {
      credential: {
        issuer: { id: grantor.did },
        credentialSubject: grantorInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(grantorInputParams, `input-grantor`);

    const recipientInputParams = {
      credential: {
        issuer: { id: recipient.did },
        credentialSubject: recipientInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(recipientInputParams, `input-recipient`);

    const grantorAcceptParams = {
      credential: {
        issuer: { id: grantor.did },
        credentialSubject: grantorAcceptInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(grantorAcceptParams, `input-grantor-accept`);

    const grantorRejectParams = {
      credential: {
        issuer: { id: grantor.did },
        credentialSubject: grantorRejectInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(grantorRejectParams, `input-grantor-reject`);

    const txProofVcParams = {
      credential: {
        issuer: { id: grantor.did },
        credentialSubject: {
          inputId: "workTokenSentTx",
          documentHash: agreementDocHash,
          values: {
            workTokenSentTx: {
                value: txHash,
                proof: proofDataBase64,
            }
          },
        },
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(txProofVcParams, `input-tx-proof`);

    const workSubmissionParams = {
      credential: {
        issuer: { id: recipient.did },
        credentialSubject: workSubmissionInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(workSubmissionParams, `input-work-submission`);

    const workAcceptParams = {
      credential: {
        issuer: { id: grantor.did },
        credentialSubject: workAcceptInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(workAcceptParams, `input-work-accept`);

    const workRejectParams = {
      credential: {
        issuer: { id: grantor.did },
        credentialSubject: workRejectInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(workRejectParams, `input-work-reject`);

    const agreementRejectParams = {
      credential: {
        issuer: { id: grantor.did },
        credentialSubject: agreementRejectInput,
        type: ['VerifiableCredential','AgreementInputCredential'],
      },
      proofFormat: 'EthereumEip712Signature2021',
    };
    await writeVc(agreementRejectParams, `input-agreement-reject`);
  } catch(e) {
    console.error("Error", e)
  }
}

main().catch(console.log)