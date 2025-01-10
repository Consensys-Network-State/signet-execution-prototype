// veramo.module.ts
import { DynamicModule, Module } from '@nestjs/common';
import { VeramoService } from './veramo.service';

@Module({})
// biome-ignore lint/complexity/noStaticOnlyClass: <explanation>
export class VeramoModule {
  static async register(): Promise<DynamicModule> {
    const modules = {
      coreModule: await import('@veramo/core'),
      didResolverModule: await import('@veramo/did-resolver'),
      credentialModule: await import('@veramo/credential-w3c'),
      resolverModule: await import('did-resolver'),
      keyDidResolver: await import('key-did-resolver')
    };

    return {
      module: VeramoModule,
      providers: [
        {
          provide: 'VERAMO_MODULES',
          useValue: modules,
        },
        VeramoService,
      ],
      exports: [VeramoService],
    };
  }
}