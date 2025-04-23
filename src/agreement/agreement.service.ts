import { Injectable } from '@nestjs/common';
import { AgreementVC, AgreementInputVC } from '@/permaweb/types';
import { createAgreement, getAgreementDocumentById, getAgreementStateById, processInput } from '@/permaweb/documents';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AgreementService {
  private wallet: any;

  constructor(private configService: ConfigService) {
    this.wallet = this.configService.get('wallet');
  }

  async createAgreement(agreementVC: AgreementVC) {
    return createAgreement(agreementVC, this.wallet);
  }

  async processInput(id: string, inputId: string, inputValue: AgreementInputVC) {
    return processInput(id, inputId, inputValue, this.wallet);
  }

  async getState(id: string) {
    return getAgreementStateById(id); 
  }

  async getAgreement(id: string) {
    return getAgreementDocumentById(id); 
  }
}