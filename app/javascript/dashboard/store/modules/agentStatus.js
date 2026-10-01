import types from '../mutation-types';
import AgentStatusAPI from '../../api/agentStatus';
import { AVAILABILITY_BY_STATUS } from 'dashboard/constants/agentStatus';

// The signed-in agent's own status in this account, with the load against the chat limit and
// today's seconds per status. fetchedAt anchors the clock that keeps the open status counting.
export const state = {
  agentStatus: 'ready',
  since: null,
  load: { active: 0, limit: 0 },
  today: {},
  fetchedAt: 0,
  projectId: null,
};

export const getters = {
  getAgentStatus: $state => $state.agentStatus,
  getLoad: $state => $state.load,
  getToday: $state => $state.today,
  getFetchedAt: $state => $state.fetchedAt,
};

export const actions = {
  // A project picks the chat limit the load is measured against; later calls reuse the last one
  fetch: async ({ commit, state: $state }, projectId = $state.projectId) => {
    try {
      const { data } = await AgentStatusAPI.get(projectId);
      commit(types.SET_AGENT_STATUS_SNAPSHOT, { ...data, projectId });
    } catch (error) {
      // Keep the last snapshot, the next poll tries again
    }
  },

  // Optimistic: the menu and the avatar follow at once, and revert if the server refuses
  set: async (
    { commit, dispatch, state: $state, rootGetters },
    { status, projectId = $state.projectId }
  ) => {
    const previous = $state.agentStatus;
    const apply = agentStatus => {
      commit(types.SET_AGENT_STATUS, agentStatus);
      commit(types.SET_CURRENT_USER_AGENT_STATUS, agentStatus, { root: true });
      dispatch(
        'agents/updateSingleAgentPresence',
        {
          id: rootGetters.getCurrentUserID,
          availabilityStatus: AVAILABILITY_BY_STATUS[agentStatus],
        },
        { root: true }
      );
    };

    apply(status);
    try {
      const { data } = await AgentStatusAPI.set(status, projectId);
      commit(types.SET_AGENT_STATUS_SNAPSHOT, { ...data, projectId });
    } catch (error) {
      apply(previous);
      throw error;
    }
  },
};

export const mutations = {
  [types.SET_AGENT_STATUS]($state, agentStatus) {
    $state.agentStatus = agentStatus;
  },
  [types.SET_AGENT_STATUS_SNAPSHOT](
    $state,
    { agent_status: agentStatus, since, load, today, projectId }
  ) {
    $state.agentStatus = agentStatus;
    $state.since = since;
    $state.load = load;
    $state.today = today;
    $state.projectId = projectId;
    $state.fetchedAt = Date.now();
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
