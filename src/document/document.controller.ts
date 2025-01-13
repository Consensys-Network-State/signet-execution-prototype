// document.controller.ts
import { Controller, Post, Body, Get, Param } from '@nestjs/common';
import { VeramoService } from '@/document/veramo.service';
import { DocumentService } from '@/document/document.service';
import { DocumentVC, DocumentSignatureVC } from '@/permaweb/types';

@Controller('document')
export class DocumentController {
    constructor(
        private readonly documentService: DocumentService,
        private readonly veramoService: VeramoService
    ) {}

    @Get('test')
    async test(@Body() data: any) {
        this.documentService.test();
    }

    @Get(':id')
    async getDocument(@Param('id') id: string) {
        return this.documentService.getDocument(id);
    }

    @Post('create')
    async createDocument(@Body() documentVC: DocumentVC) {
        const verificationResult = await this.veramoService.verifyCredential(documentVC);
        if (!verificationResult.verified) {
            throw new Error(verificationResult.error);
        }
        return this.documentService.createDocument(documentVC);
    }

    @Post('sign/:processId')
    async signDocument(
        @Body() signatureVC: DocumentSignatureVC,
        @Param('processId') processId: string
    ) {
        const verificationResult = await this.veramoService.verifyCredential(signatureVC);
        if (!verificationResult.verified) {
            throw new Error(verificationResult.error);
        }
        return this.documentService.signDocument(signatureVC, processId);
    }
}