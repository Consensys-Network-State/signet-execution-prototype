import { Controller, Post, Body, Param, Get } from '@nestjs/common';
import { DocumentService } from './document.service';
import { CreateDocumentDto, SignDocumentDto } from './document.dto';

@Controller('document')
export class DocumentController {
    constructor(private readonly documentService: DocumentService) { }

    @Get(':id')
    async getDocument(@Param('id') id: string) {
        return this.documentService.getDocument(id);
    }

    @Post('create')
    async createDocument(@Body() createDocumentDto: CreateDocumentDto) {
        return this.documentService.createDocument(createDocumentDto);
    }

    @Post('sign')
    async signDocument(@Body() signDocumentDto: SignDocumentDto) {
        return this.documentService.signDocument(signDocumentDto);
    }
}