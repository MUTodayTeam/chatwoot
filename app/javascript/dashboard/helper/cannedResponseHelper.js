/**
 * The canned responses an agent can use in a project's chats: the project's own
 * and the ones without a project, which are shared by every project.
 *
 * The composer filters here instead of asking the API per conversation because the
 * store already holds every response of the account, served from the IndexedDB
 * cache ('canned_response'), and switching conversations should not refetch it.
 * @param {Array<{project_id?: number|null}>} responses
 * @param {number|null} projectId null for an inbox outside every project
 */
export const cannedResponsesForProject = (responses, projectId) =>
  responses.filter(
    ({ project_id: responseProjectId }) =>
      !responseProjectId || responseProjectId === projectId
  );
