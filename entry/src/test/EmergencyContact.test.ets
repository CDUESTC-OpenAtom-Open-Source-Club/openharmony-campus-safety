import { describe, it, expect } from '@ohos/hypium';
import { EmergencyContactService } from '../main/ets/service/EmergencyContactService';

export default function emergencyContactTest() {
  describe('EmergencyContactTest', () => {
    it('normalizes_local_phone_before_persistence', 0, () => {
      expect(EmergencyContactService.normalizePhone(' +86 138-0013-8000 '))
        .assertEqual('+8613800138000');
    });

    it('accepts_only_supported_local_phone_formats', 0, () => {
      expect(EmergencyContactService.isValidPhone('13800138000')).assertTrue();
      expect(EmergencyContactService.isValidPhone('+8613800138000')).assertTrue();
      expect(EmergencyContactService.isValidPhone('12345')).assertFalse();
      expect(EmergencyContactService.isValidPhone('12AB5678')).assertFalse();
      expect(EmergencyContactService.isValidPhone('123456789012345678901')).assertFalse();
    });
  });
}
