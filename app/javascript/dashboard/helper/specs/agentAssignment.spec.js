import {
  buildAssignRows,
  formatAgentLoad,
  isAgentAtLimit,
  withLivePresence,
} from '../agentAssignment';

const currentUser = {
  id: 1,
  accounts: [{ id: 7, availability_status: 'busy' }],
};

const agents = [
  {
    id: 1,
    name: 'Me',
    email: 'me@example.com',
    availability_status: 'online',
    conversation_load: { assigned_count: 2, limit: 10 },
  },
  {
    id: 2,
    name: 'Poy',
    email: 'poy@example.com',
    availability_status: 'offline',
    conversation_load: { assigned_count: 10, limit: 10 },
  },
  {
    id: 3,
    name: 'Arm',
    email: 'arm@example.com',
    availability_status: 'online',
    conversation_load: { assigned_count: 0, limit: 7 },
  },
];

const teams = [
  { id: 10, name: 'CRM' },
  { id: 11, name: 'Dev' },
];

const rowsFor = (overrides = {}) =>
  buildAssignRows({
    agents,
    liveAgents: [{ id: 2, availability_status: 'online' }],
    currentUser,
    accountId: 7,
    teams,
    teamIdsByAgent: { 2: [10, 11], 3: [11] },
    query: '',
    ...overrides,
  });

describe('agentAssignment', () => {
  describe('formatAgentLoad', () => {
    it('shows the load against the limit', () => {
      expect(formatAgentLoad({ assigned_count: 3, limit: 10 })).toBe('3/10');
    });

    it('is empty without a load', () => {
      expect(formatAgentLoad(undefined)).toBe('');
    });
  });

  describe('isAgentAtLimit', () => {
    it('is true once the load reaches the limit', () => {
      expect(isAgentAtLimit({ assigned_count: 10, limit: 10 })).toBe(true);
      expect(isAgentAtLimit({ assigned_count: 12, limit: 10 })).toBe(true);
      expect(isAgentAtLimit({ assigned_count: 9, limit: 10 })).toBe(false);
      expect(isAgentAtLimit(undefined)).toBe(false);
    });
  });

  describe('withLivePresence', () => {
    it('prefers the live presence and falls back to the payload, then offline', () => {
      const result = withLivePresence(
        [
          { id: 1, availability_status: 'online' },
          { id: 2, availability_status: 'online' },
          { id: 3 },
        ],
        [{ id: 2, availability_status: 'busy' }]
      );

      expect(result.map(agent => agent.availability_status)).toEqual([
        'online',
        'busy',
        'offline',
      ]);
    });
  });

  describe('buildAssignRows', () => {
    it('orders online, busy then offline and reads presence live', () => {
      // Poy is online in the agents store; the current user is busy on this account
      expect(rowsFor().map(row => [row.name, row.availability_status])).toEqual(
        [
          ['Arm', 'online'],
          ['Poy', 'online'],
          ['Me', 'busy'],
        ]
      );
    });

    it('names the project teams each agent is in and keeps their load', () => {
      const poy = rowsFor().find(row => row.id === 2);

      expect(poy.teamNames).toEqual(['CRM', 'Dev']);
      expect(poy.conversation_load).toEqual({ assigned_count: 10, limit: 10 });
      expect(rowsFor().find(row => row.id === 1).teamNames).toEqual([]);
    });

    it('filters by the search on name and email', () => {
      expect(rowsFor({ query: ' po ' }).map(row => row.id)).toEqual([2]);
      expect(rowsFor({ query: 'arm@' }).map(row => row.id)).toEqual([3]);
      expect(rowsFor({ query: 'nobody' })).toEqual([]);
    });
  });
});
