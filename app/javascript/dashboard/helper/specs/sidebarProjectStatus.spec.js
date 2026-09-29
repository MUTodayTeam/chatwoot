import {
  getProjectOpenCount,
  getProjectUnreadCount,
  resolveCurrentProject,
} from '../sidebarProjectStatus';

const projects = [
  { id: 1, name: 'Checkin+', inboxIds: [11, 12] },
  { id: 2, name: 'MUToday', inboxIds: [21] },
];

const projectListFilters = { projectId: '1', status: 'active' };

describe('sidebarProjectStatus', () => {
  describe('resolveCurrentProject', () => {
    it('reads the project list from the route', () => {
      expect(resolveCurrentProject(projects, { projectId: '2' })).toBe(
        projects[1]
      );
    });

    it("reads a channel's project", () => {
      expect(resolveCurrentProject(projects, { inboxId: '12' })).toBe(
        projects[0]
      );
    });

    it('is null for lists that span every project', () => {
      expect(resolveCurrentProject(projects, {})).toBeNull();
      expect(resolveCurrentProject(projects, { inboxId: '99' })).toBeNull();
      expect(resolveCurrentProject(projects, { projectId: '99' })).toBeNull();
    });
  });

  describe('getProjectOpenCount', () => {
    const openCount = (filters, hasAppliedFilters = false) =>
      getProjectOpenCount({
        project: projects[0],
        filters,
        hasAppliedFilters,
        allCount: 17,
      });

    it("is the list count on the project's own open list", () => {
      expect(openCount(projectListFilters)).toBe(17);
    });

    it('is null when the count covers something else', () => {
      expect(openCount({ ...projectListFilters, status: 'open' })).toBeNull();
      expect(openCount({ ...projectListFilters, inboxId: 11 })).toBeNull();
      expect(openCount({ ...projectListFilters, labels: ['vip'] })).toBeNull();
      expect(openCount({ ...projectListFilters, projectId: '2' })).toBeNull();
      expect(openCount({ status: 'active' })).toBeNull();
      expect(openCount(projectListFilters, true)).toBeNull();
    });
  });

  describe('getProjectUnreadCount', () => {
    it("sums the unread counts of the project's channels", () => {
      const unread = { 11: 2, 12: 3, 21: 5 };

      expect(getProjectUnreadCount(projects[0], id => unread[id])).toBe(5);
      expect(getProjectUnreadCount({ inboxIds: [] }, id => unread[id])).toBe(0);
    });
  });
});
