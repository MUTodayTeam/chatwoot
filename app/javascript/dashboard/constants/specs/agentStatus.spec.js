import {
  AGENT_STATUSES,
  AVAILABILITY_BY_STATUS,
  liveAgentStatus,
} from '../agentStatus';

describe('agentStatus', () => {
  it('lists the Thaimart statuses in menu order', () => {
    expect(AGENT_STATUSES.map(status => status.value)).toEqual([
      'ready',
      'busy',
      'mini_break',
      'lunch',
      'briefing',
      'rest_room',
      'offline',
    ]);
  });

  it('derives only Ready as online', () => {
    const online = Object.keys(AVAILABILITY_BY_STATUS).filter(
      status => AVAILABILITY_BY_STATUS[status] === 'online'
    );

    expect(online).toEqual(['ready']);
  });

  describe('liveAgentStatus', () => {
    it('keeps the picked status while it agrees with live presence', () => {
      expect(
        liveAgentStatus({ agent_status: 'lunch', availability_status: 'busy' })
      ).toBe('lunch');
    });

    it('is offline whenever presence says offline', () => {
      expect(
        liveAgentStatus({
          agent_status: 'ready',
          availability_status: 'offline',
        })
      ).toBe('offline');
    });

    it('follows live presence when the snapshot has gone stale', () => {
      expect(
        liveAgentStatus({
          agent_status: 'lunch',
          availability_status: 'online',
        })
      ).toBe('ready');
    });

    it('falls back to the 3-way presence without a picked status', () => {
      expect(liveAgentStatus({ availability_status: 'busy' })).toBe('busy');
    });
  });
});
