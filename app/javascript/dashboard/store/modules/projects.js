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

// Rails does not run the params wrapper on multipart requests, so every key is
// namespaced by hand. An empty inbox selection still has to reach the server,
// and a form cannot carry an empty array — one blank entry stands in for it.
const buildProjectForm = (
  { name, description, color, inboxIds = [] },
  logo
) => {
  const form = new FormData();
  form.append('project[name]', name ?? '');
  form.append('project[description]', description ?? '');
  form.append('project[color]', color ?? '');
  if (inboxIds.length) {
    inboxIds.forEach(id => form.append('project[inbox_ids][]', id));
  } else {
    form.append('project[inbox_ids][]', '');
  }
  form.append('project[avatar]', logo);
  return form;
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

  create: async function create({ commit }, { logo, ...projectObj }) {
    commit(types.SET_PROJECTS_UI_FLAG, { isCreating: true });
    try {
      const response = logo
        ? await ProjectsAPI.createWithLogo(buildProjectForm(projectObj, logo))
        : await ProjectsAPI.create(snakecaseKeys(projectObj));
      commit(types.ADD_PROJECT, camelcaseKeys(response.data));
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_PROJECTS_UI_FLAG, { isCreating: false });
    }
  },

  update: async function update({ commit }, { id, logo, ...projectParams }) {
    commit(types.SET_PROJECTS_UI_FLAG, { isUpdating: true });
    try {
      const response = logo
        ? await ProjectsAPI.updateWithLogo(
            id,
            buildProjectForm(projectParams, logo)
          )
        : await ProjectsAPI.update(id, snakecaseKeys(projectParams));
      commit(types.EDIT_PROJECT, camelcaseKeys(response.data));
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_PROJECTS_UI_FLAG, { isUpdating: false });
    }
  },

  deleteLogo: async function deleteLogo({ commit }, projectId) {
    commit(types.SET_PROJECTS_UI_FLAG, { isUpdating: true });
    try {
      const response = await ProjectsAPI.deleteLogo(projectId);
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
