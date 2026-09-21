import ApiClient from './ApiClient';

class LiveChatRules extends ApiClient {
  constructor() {
    super('live_chat_rules', { accountScoped: true });
  }
}

export default new LiveChatRules();
