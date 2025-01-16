// document.module.ts
import { Module } from '@nestjs/common';
import { DocumentController } from '@/document/document.controller';
import { DocumentService } from '@/document/document.service';
import { VeramoService } from '@/document/veramo.service';

@Module({
    controllers: [DocumentController],
    providers: [
        DocumentService,
        VeramoService
    ],
})
export class DocumentModule {}