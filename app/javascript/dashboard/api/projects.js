import ApiClient from './ApiClient';

class Projects extends ApiClient {
  constructor() {
    super('projects', { accountScoped: true });
  }
}

export default new Projects();
