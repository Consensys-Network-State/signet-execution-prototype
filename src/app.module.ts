import { Module } from '@nestjs/common';
import { AppController } from '@/app.controller';
import { AppService } from '@/app.service';
import { DocumentController } from '@/document/document.controller';
import { DocumentService } from '@/document/document.service';
import { DocumentModule } from '@/document/document.module';
import { ConfigurationModule } from '@/config/configuration.module';

@Module({
  imports: [DocumentModule, ConfigurationModule],
  controllers: [AppController, DocumentController],
  providers: [AppService, DocumentService],
})
export class AppModule {}
