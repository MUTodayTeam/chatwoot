/* global axios */
import ApiClient from './ApiClient';

class CaseCategoriesAPI extends ApiClient {
  constructor() {
    super('case_categories', { accountScoped: true });
  }

  // q (any level), inquiry_type
  get(params = {}, { signal } = {}) {
    return axios.get(this.url, { params, signal });
  }

  // Blobs keep the UTF-8 BOM, which Excel needs to read Thai text
  downloadTemplate() {
    return axios.get(`${this.url}/template.csv`, { responseType: 'blob' });
  }

  export() {
    return axios.get(`${this.url}/export.csv`, { responseType: 'blob' });
  }

  import(file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(`${this.url}/import`, formData);
  }
}

export default new CaseCategoriesAPI();
