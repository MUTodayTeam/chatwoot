import axios from 'axios';
import { actions, getters, mutations } from '../agentStatus';
import types from '../../mutation-types';

global.axios = axios;
vi.mock('axios');

const snapshot = {
  agent_status: 'lunch',
  availability: 'busy',
  since: '2026-10-01T05:00:00Z',
  load: { active: 2, limit: 10 },
  today: { ready: 60, lunch: 30, online_total: 90 },
};

describe('agentStatus store', () => {
  describe('actions', () => {
    const commit = vi.fn();
    const dispatch = vi.fn();
    const rootGetters = { getCurrentUserID: 4 };

    beforeEach(() => {
      commit.mockReset();
      dispatch.mockReset();
      axios.get.mockReset();
      axios.put.mockReset();
    });

    it('fetch reads the status for the project and stores the snapshot', async () => {
      axios.get.mockResolvedValue({ data: snapshot });

      await actions.fetch({ commit, state: { projectId: null } }, 5);

      expect(axios.get).toHaveBeenCalledWith(expect.any(String), {
        params: { project_id: 5 },
      });
      expect(commit).toHaveBeenCalledWith(types.SET_AGENT_STATUS_SNAPSHOT, {
        ...snapshot,
        projectId: 5,
      });
    });

    it('fetch reuses the last project when none is given', async () => {
      axios.get.mockResolvedValue({ data: snapshot });

      await actions.fetch({ commit, state: { projectId: 8 } });

      expect(axios.get).toHaveBeenCalledWith(expect.any(String), {
        params: { project_id: 8 },
      });
    });

    it('fetch keeps the last snapshot when the request fails', async () => {
      axios.get.mockRejectedValue(new Error('offline'));

      await actions.fetch({ commit, state: { projectId: null } }, 5);

      expect(commit).not.toHaveBeenCalled();
    });

    it('set follows at once, then stores what the server answers', async () => {
      axios.put.mockResolvedValue({ data: snapshot });

      await actions.set(
        { commit, dispatch, state: { agentStatus: 'ready' }, rootGetters },
        { status: 'lunch', projectId: 5 }
      );

      expect(axios.put).toHaveBeenCalledWith(expect.any(String), {
        agent_status: 'lunch',
        project_id: 5,
      });
      expect(commit.mock.calls).toEqual([
        [types.SET_AGENT_STATUS, 'lunch'],
        [types.SET_CURRENT_USER_AGENT_STATUS, 'lunch', { root: true }],
        [types.SET_AGENT_STATUS_SNAPSHOT, { ...snapshot, projectId: 5 }],
      ]);
      expect(dispatch).toHaveBeenCalledWith(
        'agents/updateSingleAgentPresence',
        { id: 4, availabilityStatus: 'busy' },
        { root: true }
      );
    });

    it('set reverts to the previous status and throws when the server refuses', async () => {
      axios.put.mockRejectedValue(new Error('422'));

      await expect(
        actions.set(
          { commit, dispatch, state: { agentStatus: 'ready' }, rootGetters },
          { status: 'lunch', projectId: null }
        )
      ).rejects.toThrow('422');

      expect(commit.mock.calls).toEqual([
        [types.SET_AGENT_STATUS, 'lunch'],
        [types.SET_CURRENT_USER_AGENT_STATUS, 'lunch', { root: true }],
        [types.SET_AGENT_STATUS, 'ready'],
        [types.SET_CURRENT_USER_AGENT_STATUS, 'ready', { root: true }],
      ]);
      expect(dispatch).toHaveBeenLastCalledWith(
        'agents/updateSingleAgentPresence',
        { id: 4, availabilityStatus: 'online' },
        { root: true }
      );
    });
  });

  describe('mutations', () => {
    it('stores a snapshot and stamps when it arrived', () => {
      const state = {};

      mutations[types.SET_AGENT_STATUS_SNAPSHOT](state, {
        ...snapshot,
        projectId: 5,
      });

      expect(state).toMatchObject({
        agentStatus: 'lunch',
        load: snapshot.load,
        today: snapshot.today,
        projectId: 5,
      });
      expect(state.fetchedAt).toBeGreaterThan(0);
    });
  });

  describe('getters', () => {
    it('reads the status, load and today', () => {
      const state = {
        agentStatus: 'busy',
        load: snapshot.load,
        today: snapshot.today,
        fetchedAt: 9,
      };

      expect(getters.getAgentStatus(state)).toBe('busy');
      expect(getters.getLoad(state)).toEqual(snapshot.load);
      expect(getters.getToday(state)).toEqual(snapshot.today);
      expect(getters.getFetchedAt(state)).toBe(9);
    });
  });
});
