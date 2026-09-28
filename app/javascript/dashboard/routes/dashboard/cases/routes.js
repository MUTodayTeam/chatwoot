import {
  CONVERSATION_PERMISSIONS,
  ROLES,
} from 'dashboard/constants/permissions';
import { frontendURL } from '../../../helper/URLHelper';
import CasesIndex from './pages/CasesIndex.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/cases'),
    name: 'cases_index',
    component: CasesIndex,
    meta: {
      permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    },
  },
];
