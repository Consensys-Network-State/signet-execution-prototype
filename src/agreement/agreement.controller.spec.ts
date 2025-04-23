import { Test, TestingModule } from '@nestjs/testing';
import { AgreementController } from './agreement.controller';
import { AgreementService } from './agreement.service';

describe('AgreementController', () => {
  let controller: AgreementController;
  let service: AgreementService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AgreementController],
      providers: [AgreementService],
    }).compile();

    controller = module.get<AgreementController>(AgreementController);
    service = module.get<AgreementService>(AgreementService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
