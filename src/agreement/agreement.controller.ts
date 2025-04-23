// document.controller.ts
import { Controller, Post, Body, Get, Param, BadRequestException, Query } from '@nestjs/common';
import { VeramoService } from '@/veramo/veramo.service';
import { AgreementVC, AgreementInputVC } from '@/permaweb/types';
import { AgreementService } from '@/agreement/agreement.service';

@Controller('agreements')
export class AgreementController {
    constructor(
        private readonly agreementService: AgreementService,
        private readonly veramoService: VeramoService
    ) {}

    @Get(':id')
    async getAgreement(@Param('id') id: string) {
        // id here is actually the process/actorId
        return this.agreementService.getAgreement(id);
    }

    @Post()
    async createAgreement(@Body() agreementVC: AgreementVC) {
        const verificationResult = await this.veramoService.verifyCredential(agreementVC);
        if (!verificationResult.verified) {
          throw new BadRequestException(verificationResult.error);
        }
        return this.agreementService.createAgreement(agreementVC);
    }

    @Post(':id/input')
    async processInput(
        @Body() payload: { inputId: string, inputValue: AgreementInputVC },
        @Param('id') id: string
    ) {
        const verificationResult = await this.veramoService.verifyCredential(payload.inputValue);
        if (!verificationResult.verified) {
          throw new BadRequestException(verificationResult.error);
        }
        return this.agreementService.processInput(id, payload.inputId, payload.inputValue);
    }

    @Get(':id/state')
    async getState(@Param('id') id: string) {
        // This maps to the "GetState" handler in the Lua actor
        return this.agreementService.getState(id);
    }

    @Get()
    async findByContributor(@Query('contributor') contributor: string) {
        if (!contributor) {
            throw new BadRequestException('Missing collaborator address');
        }
        return this.agreementService.findByContributor(contributor);
    }
}