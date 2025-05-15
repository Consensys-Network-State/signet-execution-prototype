import { Injectable, NotFoundException, InternalServerErrorException } from '@nestjs/common';
import { AgreementVC, AgreementInputVC, AgreementState, AgreementRecord } from '@/permaweb/types';
import { createAgreement, getAgreementDocumentById, getAgreementStateById, processInput } from '@/permaweb/documents';
import { ConfigService } from '@nestjs/config';
import { upsertAgreementRecord, findAgreementById, findAgreementsByContributor } from '@/db/agreement.repository';
import asyncRetry from 'async-retry';

@Injectable()
export class AgreementService {
  private wallet: any;

  constructor(private configService: ConfigService) {
    this.wallet = this.configService.get('wallet');
  }

  async createAgreement(agreementVC: AgreementVC) {
    const { processId } = await createAgreement(agreementVC, this.wallet);
    return queryAndUpsertAgreementRecord(processId);
  }

  async processInput(id: string, inputId: string, inputValue: AgreementInputVC) {
    // sanity check
    const agreement = await findAgreementById(id);
    if (!agreement) {
      throw new NotFoundException('Agreement not found in our records');
    }

    const result = await processInput(id, inputId, inputValue, this.wallet);
    if (!result.success) {
      throw new InternalServerErrorException(`Failed to process input: "${result.error}"`);
    }
    // After processing input, update the agreement record in Mongo.
    // There is no need to fetch the document, as it doesn't change after initialization.
    const updatedState = await queryAndUpsertAgreementRecord(id, false);
    return {
      ...result,
      updatedState,
    };
  }

  async getState(id: string) {
    return getAgreementStateById(id); 
  }

  async getAgreement(id: string) {
    const agreement = await findAgreementById(id);
    // TODO: do we want to lazy-fetch the agreement info from AO if we don't find the record in our DB?
    // return getAgreementDocumentById(id); 
    if (!agreement) {
      throw new NotFoundException('Agreement not found in our records');
    }
    return agreement;
  }

  async findByContributor(address: string) {
    // Normalize address to lowercase for consistent querying
    return findAgreementsByContributor(address);
  }
}

async function queryAndUpsertAgreementRecord(processId: string, fetchDocument: boolean = true): Promise<AgreementRecord> {
  // Query with async-retry
  let agreementDoc = undefined;
  let agreementDocHash = undefined;
  if (fetchDocument) {
    const document = await asyncRetry(
      async (bail, attempt) => {
        try {
          return await getAgreementDocumentById(processId);
        } catch (err) {
          console.warn(`[getAgreementDocumentById] attempt ${attempt} failed:`, err);
          throw err;
        }
      },
      { retries: 5, minTimeout: 200, factor: 2 }
    );

    agreementDocHash = document.DocumentHash;
    const agreementVC = JSON.parse(document.Document);
    agreementDoc = JSON.parse(atob(agreementVC.credentialSubject.agreement));
  } else {
    // grab the document from our records
    const agreementRecord = await findAgreementById(processId);
    agreementDoc = agreementRecord?.document;
    agreementDocHash = agreementRecord?.documentHash;
  }
  const state = await asyncRetry(
    async (bail, attempt) => {
      try {
        return await getAgreementStateById(processId);
      } catch (err) {
        console.warn(`[getAgreementStateById] attempt ${attempt} failed:`, err);
        throw err;
      }
    },
    { retries: 5, minTimeout: 200, factor: 2 }
  );

  const contributors = extractContributors(agreementDoc, state);
  const now = new Date();
  const record: AgreementRecord = {
    id: processId,
    document: agreementDoc,
    documentHash: agreementDocHash,
    state,
    contributors,
    createdAt: now,
    updatedAt: now,
  };
  await upsertAgreementRecord(record);
  return record;
}

function extractContributors(agreement: AgreementVC, state: AgreementState): string[] {
  const addressVars = Object.entries(state?.Variables || {})
    .filter(([_, v]: any) => v.type === 'address')
    .map(([k, v]: any) => ({ key: k, value: v.value }));

  // Find all input issuers that reference a variable
  const inputs = agreement?.execution?.inputs || {};
  const issuerVarNames = Object.values(inputs)
    .map((input: any) => input.issuer)
    .filter((issuer: any) => typeof issuer === 'string' && issuer.startsWith('${variables.') && issuer.endsWith('.value}'))
    .map((issuer: string) => issuer.replace('${variables.', '').replace('.value}', ''));

  // For each issuer variable, get its value from addressVars
  const contributors = issuerVarNames
    .map(varName => addressVars.find(v => v.key === varName)?.value)
    .filter((v): v is string => typeof v === 'string');

  // return unique contributors. We lowercase them to be able to consistently query the database.
  return [...new Set(contributors)].map(c => c.toLowerCase());
}