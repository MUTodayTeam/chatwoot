import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/live-chat-rules'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'live_chat_rules_wrapper',
          meta: {
            permissions: ['administrator'],
          },
          redirect: to => {
            return { name: 'live_chat_rules_index', params: to.params };
          },
        },
        {
          path: 'index',
          name: 'live_chat_rules_index',
          meta: {
            permissions: ['administrator'],
          },
          component: Index,
        },
      ],
    },
  ],
};
