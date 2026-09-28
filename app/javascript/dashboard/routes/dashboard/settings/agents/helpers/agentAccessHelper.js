// The Agents settings list shows which teams each agent is in and which projects those
// teams are entitled to, since a project reaches an agent only through a team.

export const ALL_OPTIONS_VALUE = '';

export const mapTeamIdsByAgent = (teams, membersOf) =>
  teams.reduce((teamIdsByAgent, team) => {
    membersOf(team.id).forEach(member => {
      teamIdsByAgent[member.id] = [
        ...(teamIdsByAgent[member.id] ?? []),
        team.id,
      ];
    });
    return teamIdsByAgent;
  }, {});

export const projectsForTeams = (projects, teamIds) =>
  projects.filter(project =>
    (project.teamIds ?? []).some(teamId => teamIds.includes(teamId))
  );

export const filterAgents = (agents, { role, projectId }, projectIdsOf) =>
  agents.filter(
    agent =>
      (role === ALL_OPTIONS_VALUE || agent.role === role) &&
      (projectId === ALL_OPTIONS_VALUE ||
        projectIdsOf(agent).includes(projectId))
  );
