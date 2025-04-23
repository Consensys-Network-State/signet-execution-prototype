// document.module.ts
import { Module } from '@nestjs/common';
import { AgreementController } from '@/agreement/agreement.controller';
import { AgreementService } from '@/agreement/agreement.service';
import { VeramoService } from '@/veramo/veramo.service';

@Module({
    controllers: [AgreementController],
    providers: [
        AgreementService,
        VeramoService
    ],
    exports: [AgreementService],
})
export class AgreementModule {}