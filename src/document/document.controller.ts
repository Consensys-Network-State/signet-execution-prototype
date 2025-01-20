// document.controller.ts
import { Controller, Post, Body, Get, Param } from '@nestjs/common';
import { VeramoService } from '@/document/veramo.service';
import { DocumentService } from '@/document/document.service';
import { DocumentVC, DocumentSignatureVC } from '@/permaweb/types';

@Controller('documents')
export class DocumentController {
    constructor(
        private readonly documentService: DocumentService,
        private readonly veramoService: VeramoService
    ) {}

    @Get(':id')
    async getDocument(@Param('id') id: string) {
        // id here is actually the process/actorId
        return this.documentService.getDocument(id);
    }

    @Post()
    async createDocument(@Body() documentVC: DocumentVC) {
        const verificationResult = await this.veramoService.verifyCredential(documentVC);
        if (!verificationResult.verified) {
            throw new Error(verificationResult.error);
        }
        return this.documentService.createDocument(documentVC);
    }

    @Post(':id/sign')
    async signDocument(
        @Body() signatureVC: DocumentSignatureVC,
        @Param('id') id: string
    ) {
        // id here is actually the process/actorId
        const verificationResult = await this.veramoService.verifyCredential(signatureVC);
        if (!verificationResult.verified) {
            throw new Error(verificationResult.error);
        }
        return this.documentService.signDocument(signatureVC, id);
    }
}