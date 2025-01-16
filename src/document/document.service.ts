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
    return createDocument(documentVC, this.wallet);
  }

  async signDocument(signatureVC: DocumentSignatureVC, processId: string) {
    return signDocument(signatureVC, processId, this.wallet);
  }

  async getDocument(id: string) {
    return getDocumentById(id); 
  }
}