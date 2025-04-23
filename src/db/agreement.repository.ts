import { getDb } from './mongo';
import { AgreementVC, AgreementState, AgreementRecord } from '@/permaweb/types';

const COLLECTION = 'agreements';

export async function insertAgreement(agreement: AgreementVC) {
  const db = await getDb();
  return db.collection(COLLECTION).insertOne(agreement);
}

export async function findAgreementById(id: string) {
  const db = await getDb();
  return db.collection(COLLECTION).findOne({ id });
}

export async function updateAgreementState(id: string, state: AgreementState) {
  const db = await getDb();
  return db.collection(COLLECTION).updateOne(
    { id },
    { $set: { ...state } },
    { upsert: true }
  );
}

export async function insertAgreementState(id: string, state: AgreementState) {
  const db = await getDb();
  return db.collection(COLLECTION).insertOne({ id, ...state });
}

export async function deleteAgreementById(id: string) {
  const db = await getDb();
  return db.collection(COLLECTION).deleteOne({ id });
}

export async function upsertAgreementRecord(record: AgreementRecord) {
  const db = await getDb();
  return db.collection(COLLECTION).updateOne(
    { id: record.id },
    { $set: { ...record } },
    { upsert: true }
  );
} 