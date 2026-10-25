import { describe, it, expect } from '@ohos/hypium';
import { AiProviders, AiConfig, AiProtocol } from '../main/ets/model/AiConfig';
import { AiProtocolService } from '../main/ets/service/AiProtocolService';

export default function aiProtocolTest() {
  describe('AiProtocolSecurity', () => {
    it('blocks_public_http_and_requires_local_opt_in', 0, () => {
      const config: AiConfig = AiProviders.defaults(0);
      config.model = 'fixture'; config.apiKey = 'fixture';
      config.endpoint = 'http://192.168.1.20:11434/api/chat';
      expect(AiProtocolService.validate(config) !== '').assertTrue();
      config.allowLocalHttp = true;
      expect(AiProtocolService.validate(config)).assertEqual('');
      config.endpoint = 'http://example.com/api/chat';
      expect(AiProtocolService.validate(config) !== '').assertTrue();
    });
    it('rejects_header_injection_and_url_tokens', 0, () => {
      const config: AiConfig = AiProviders.defaults(0);
      config.model = 'fixture'; config.apiKey = 'bad\r\nHeader: injected';
      expect(AiProtocolService.validate(config) !== '').assertTrue();
      config.apiKey = 'fixture'; config.endpoint += '?key=secret';
      expect(AiProtocolService.validate(config) !== '').assertTrue();
    });
    it('parses_supported_text_responses', 0, () => {
      expect(AiProtocolService.parse(AiProtocol.OLLAMA, '{"message":{"content":"ok"}}')).assertEqual('ok');
      expect(AiProtocolService.parse(AiProtocol.CLAUDE, '{"content":[{"type":"text","text":"ok"}]}')).assertEqual('ok');
      expect(AiProtocolService.parse(AiProtocol.OPENAI, '{"choices":[{"message":{"content":"ok"}}]}')).assertEqual('ok');
    });
  });
}
