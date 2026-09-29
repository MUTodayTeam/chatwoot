/* global axios */
import ApiClient from './ApiClient';

class CasesAPI extends ApiClient {
  constructor() {
    super('cases', { accountScoped: true });
  }

  // project_id, team_id, contact_id, status, mine, page
  get(params = {}, { signal } = {}) {
    return axios.get(this.url, { params, signal });
  }
}

export default new CasesAPI();
