/* global axios */
import ApiClient from './ApiClient';

class AgentStatusAPI extends ApiClient {
  constructor() {
    super('agent_status', { accountScoped: true });
  }

  get(projectId) {
    return axios.get(this.url, { params: { project_id: projectId } });
  }

  set(agentStatus, projectId) {
    return axios.put(this.url, {
      agent_status: agentStatus,
      project_id: projectId,
    });
  }
}

export default new AgentStatusAPI();
