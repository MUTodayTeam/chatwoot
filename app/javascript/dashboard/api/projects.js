/* global axios */
import ApiClient from './ApiClient';

const MULTIPART = { headers: { 'Content-Type': 'multipart/form-data' } };

class Projects extends ApiClient {
  constructor() {
    super('projects', { accountScoped: true });
  }

  // A logo can only travel as multipart, and Rails does not wrap multipart
  // params, so these payloads name their keys project[...] themselves.
  createWithLogo(formData) {
    return axios.post(this.url, formData, MULTIPART);
  }

  updateWithLogo(id, formData) {
    return axios.patch(`${this.url}/${id}`, formData, MULTIPART);
  }

  deleteLogo(id) {
    return axios.delete(`${this.url}/${id}/avatar`);
  }
}

export default new Projects();
