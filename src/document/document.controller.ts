import { Controller, Post, Body, Param, Get } from '@nestjs/common';
import { DocumentService } from './document.service';
import { DocumentVC, DocumentSignature } from '@/permaweb/types';

@Controller('document')
export class DocumentController {
    constructor(private readonly documentService: DocumentService) { }

    @Get(':id')
    async getDocument(@Param('id') id: string) {
        return this.documentService.getDocument(id);
    }

    @Post('create')
    async createDocument(@Body() document: DocumentVC) {
        return this.documentService.createDocument(document);
    }

    @Post('sign/:processId')
    async signDocument(
        @Body() signature: DocumentSignature,
        @Param('processId') processId: string
    ) {
        return this.documentService.signDocument(signature, processId);
    }
}