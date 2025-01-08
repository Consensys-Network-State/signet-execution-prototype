import { Injectable } from '@nestjs/common';
import { Document, DocumentSignature } from '@/permaweb/types';
import { createDocument, signDocument, getDocumentById } from '@/permaweb/documents';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class DocumentService {
  private wallet: any;

  constructor(private configService: ConfigService) {
    this.wallet = this.configService.get('wallet');
  }

  async createDocument(document: Omit<Document, 'id'>) {
    const wallet = this.wallet;
    return createDocument(document, wallet);
  }

  async signDocument(signature: DocumentSignature) {
    const wallet = this.wallet;
    return signDocument(signature, wallet);
  }

  async getDocument(id: string) {
    return getDocumentById(id); 
  }
}