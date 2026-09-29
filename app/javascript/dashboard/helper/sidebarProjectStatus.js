import wootConstants from 'dashboard/constants/globals';
import { findProjectForInbox } from 'dashboard/helper/conversationListRow';

// The app header's current project (CDP spec §1): the project whose list is open, or the
// project of the channel whose list is open. Any other list spans every project.
export const resolveCurrentProject = (projects, { projectId, inboxId }) => {
  if (projectId) {
    return projects.find(project => project.id === Number(projectId)) || null;
  }
  if (inboxId) return findProjectForInbox(projects, Number(inboxId));
  return null;
};

/**
 * The project's open conversations, when the chat list's count says exactly that: the
 * list is the project's own, on the Open status, not narrowed any further. Otherwise
 * null, since no loaded count covers the whole project.
 * @param {Object} params
 * @param {Object} params.project
 * @param {Object} params.filters - The chat list's filters (getChatListFilters)
 * @param {boolean} params.hasAppliedFilters - Advanced filters narrow the count
 * @param {number} params.allCount - The chat list's "All" tab count
 */
export const getProjectOpenCount = ({
  project,
  filters,
  hasAppliedFilters,
  allCount,
}) => {
  const isProjectOpenList =
    !hasAppliedFilters &&
    Number(filters.projectId) === project.id &&
    filters.status === wootConstants.STATUS_TYPE.OPEN &&
    !filters.inboxId &&
    !filters.teamId &&
    !filters.labels?.length &&
    !filters.conversationType;
  return isProjectOpenList ? allCount : null;
};

// The sidebar badge's count: unread conversations across the project's channels.
export const getProjectUnreadCount = (project, unreadCountOf) =>
  (project.inboxIds || []).reduce(
    (total, inboxId) => total + (unreadCountOf(inboxId) || 0),
    0
  );
