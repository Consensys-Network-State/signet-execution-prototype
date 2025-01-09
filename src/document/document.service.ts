import { Injectable } from '@nestjs/common';
import { DocumentVC, DocumentSignatureVC } from '@/permaweb/types';
import { createDocument, signDocument, getDocumentById } from '@/permaweb/documents';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class DocumentService {
  private wallet: any;

  constructor(private configService: ConfigService) {
    this.wallet = this.configService.get('wallet');
  }

  async createDocument(documentVC: DocumentVC) {
    const wallet = this.wallet;
    return createDocument(documentVC, wallet);
  }

  async signDocument(signatureVC: DocumentSignatureVC, processId: string) {
    const wallet = this.wallet;
    return signDocument(signatureVC, processId, wallet);
  }

  async getDocument(id: string) {
    return getDocumentById(id); 
  }
}