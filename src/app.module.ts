// app.module.ts
import { Module } from '@nestjs/common';
import { AppController } from '@/app.controller';
import { AppService } from '@/app.service';
import { AgreementModule } from '@/agreement/agreement.module';
import { ConfigurationModule } from '@/config/configuration.module';

@Module({
  imports: [
    AgreementModule,
    ConfigurationModule
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}