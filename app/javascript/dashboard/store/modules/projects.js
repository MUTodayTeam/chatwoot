import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ProjectsAPI from '../../api/projects';
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
  getProjects(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getProjectById: _state => id => {
    return _state.records.find(record => record.id === Number(id)) || {};
  },
};

export const actions = {
  get: async function get({ commit }) {
    commit(types.SET_PROJECTS_UI_FLAG, { isFetching: true });
    try {
      const response = await ProjectsAPI.get();
      commit(types.SET_PROJECTS, camelcaseKeys(response.data));
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_PROJECTS_UI_FLAG, { isFetching: false });
    }
  },

  create: async function create({ commit }, projectObj) {
    commit(types.SET_PROJECTS_UI_FLAG, { isCreating: true });
    try {
      const response = await ProjectsAPI.create(snakecaseKeys(projectObj));
      commit(types.ADD_PROJECT, camelcaseKeys(response.data));
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_PROJECTS_UI_FLAG, { isCreating: false });
    }
  },

  update: async function update({ commit }, { id, ...projectParams }) {
    commit(types.SET_PROJECTS_UI_FLAG, { isUpdating: true });
    try {
      const response = await ProjectsAPI.update(
        id,
        snakecaseKeys(projectParams)
      );
      commit(types.EDIT_PROJECT, camelcaseKeys(response.data));
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_PROJECTS_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteProject({ commit }, projectId) {
    commit(types.SET_PROJECTS_UI_FLAG, { isDeleting: true });
    try {
      await ProjectsAPI.delete(projectId);
      commit(types.DELETE_PROJECT, projectId);
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_PROJECTS_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_PROJECTS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_PROJECTS]: MutationHelpers.set,
  [types.ADD_PROJECT]: MutationHelpers.create,
  [types.EDIT_PROJECT]: MutationHelpers.update,
  [types.DELETE_PROJECT]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
