import { Controller, Post, Body, Param, Get } from '@nestjs/common';
import { DocumentService } from './document.service';
import { DocumentVC, DocumentSignatureVC } from '@/permaweb/types';

@Controller('document')
export class DocumentController {
    constructor(private readonly documentService: DocumentService) { }

    @Get(':id')
    async getDocument(@Param('id') id: string) {
        return this.documentService.getDocument(id);
    }

    @Post('create')
    async createDocument(@Body() documentVC: DocumentVC) {
        return this.documentService.createDocument(documentVC);
    }

    @Post('sign/:processId')
    async signDocument(
        @Body() signatureVC: DocumentSignatureVC,
        @Param('processId') processId: string
    ) {
        return this.documentService.signDocument(signatureVC, processId);
    }
}