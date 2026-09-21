import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import LiveChatRulesAPI from '../../api/liveChatRules';
import { throwErrorMessage } from '../utils/api';
import camelcaseKeys from 'camelcase-keys';
import snakecaseKeys from 'snakecase-keys';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getLiveChatRules(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function get({ commit }) {
    commit(types.SET_LIVE_CHAT_RULES_UI_FLAG, { isFetching: true });
    try {
      const response = await LiveChatRulesAPI.get();
      commit(types.SET_LIVE_CHAT_RULES, camelcaseKeys(response.data));
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_LIVE_CHAT_RULES_UI_FLAG, { isFetching: false });
    }
  },

  create: async function create({ commit }, ruleObj) {
    commit(types.SET_LIVE_CHAT_RULES_UI_FLAG, { isCreating: true });
    try {
      const response = await LiveChatRulesAPI.create(snakecaseKeys(ruleObj));
      commit(types.ADD_LIVE_CHAT_RULE, camelcaseKeys(response.data));
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_LIVE_CHAT_RULES_UI_FLAG, { isCreating: false });
    }
  },

  update: async function update({ commit }, { id, ...ruleParams }) {
    commit(types.SET_LIVE_CHAT_RULES_UI_FLAG, { isUpdating: true });
    try {
      const response = await LiveChatRulesAPI.update(
        id,
        snakecaseKeys(ruleParams)
      );
      commit(types.EDIT_LIVE_CHAT_RULE, camelcaseKeys(response.data));
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_LIVE_CHAT_RULES_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteRule({ commit }, ruleId) {
    commit(types.SET_LIVE_CHAT_RULES_UI_FLAG, { isDeleting: true });
    try {
      await LiveChatRulesAPI.delete(ruleId);
      commit(types.DELETE_LIVE_CHAT_RULE, ruleId);
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_LIVE_CHAT_RULES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_LIVE_CHAT_RULES_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_LIVE_CHAT_RULES]: MutationHelpers.set,
  [types.ADD_LIVE_CHAT_RULE]: MutationHelpers.create,
  [types.EDIT_LIVE_CHAT_RULE]: MutationHelpers.update,
  [types.DELETE_LIVE_CHAT_RULE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
