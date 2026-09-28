import {
  ALL_OPTIONS_VALUE,
  filterAgents,
  mapTeamIdsByAgent,
  projectsForTeams,
} from './agentAccessHelper';

const teams = [{ id: 1 }, { id: 2 }, { id: 3 }];
const members = { 1: [{ id: 10 }, { id: 11 }], 2: [{ id: 11 }], 3: [] };
const projects = [
  { id: 100, teamIds: [1] },
  { id: 200, teamIds: [2, 3] },
  { id: 300, teamIds: [] },
  { id: 400 },
];

describe('mapTeamIdsByAgent', () => {
  it('collects every team an agent is a member of', () => {
    expect(mapTeamIdsByAgent(teams, id => members[id])).toEqual({
      10: [1],
      11: [1, 2],
    });
  });
});

describe('projectsForTeams', () => {
  it('returns the projects entitled to any of the teams', () => {
    expect(projectsForTeams(projects, [2]).map(p => p.id)).toEqual([200]);
    expect(projectsForTeams(projects, [1, 3]).map(p => p.id)).toEqual([
      100, 200,
    ]);
  });

  it('returns nothing for an agent without a team', () => {
    expect(projectsForTeams(projects, [])).toEqual([]);
  });
});

describe('filterAgents', () => {
  const agents = [
    { id: 10, role: 'agent' },
    { id: 11, role: 'administrator' },
    { id: 12, role: 'agent' },
  ];
  const projectIds = { 10: [100], 11: [100, 200], 12: [] };
  const projectIdsOf = agent => projectIds[agent.id];
  const ids = filters =>
    filterAgents(agents, filters, projectIdsOf).map(a => a.id);

  it('keeps everyone when no filter is picked', () => {
    expect(
      ids({ role: ALL_OPTIONS_VALUE, projectId: ALL_OPTIONS_VALUE })
    ).toEqual([10, 11, 12]);
  });

  it('filters by role', () => {
    expect(ids({ role: 'agent', projectId: ALL_OPTIONS_VALUE })).toEqual([
      10, 12,
    ]);
  });

  it('filters by project', () => {
    expect(ids({ role: ALL_OPTIONS_VALUE, projectId: 200 })).toEqual([11]);
  });

  it('combines both filters', () => {
    expect(ids({ role: 'agent', projectId: 100 })).toEqual([10]);
  });
});
