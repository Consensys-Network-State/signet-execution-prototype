import { getDb } from './mongo';
import { AgreementVC, AgreementState, AgreementRecord } from '@/permaweb/types';

const COLLECTION = 'agreements';

export async function findAgreementById(id: string) {
  const db = await getDb();
  return db.collection(COLLECTION).findOne({ id });
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

export async function findAgreementsByContributor(address: string) {
  const db = await getDb();
  return db.collection(COLLECTION)
    .find({ contributors: address.toLowerCase() })
    .toArray();
} 