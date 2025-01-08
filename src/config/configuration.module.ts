import { Module, Global } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import walletConfig from './wallet.config';

@Global()
@Module({
    imports: [
        ConfigModule.forRoot({
            load: [walletConfig],
            isGlobal: true,
        }),
    ],
    exports: [ConfigModule],
})
export class ConfigurationModule {}