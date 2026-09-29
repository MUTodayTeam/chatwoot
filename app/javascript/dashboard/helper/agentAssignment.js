import { picoSearch } from '@chatwoot/pico-search';
import {
  getAgentsByUpdatedPresence,
  getSortedAgentsByAvailability,
} from 'dashboard/helper/agentHelper';

// The presence an agent can have and the dot each one shows, as the Avatar status dot.
export const PRESENCE_DOT_CLASSES = Object.freeze({
  online: 'bg-n-teal-10',
  busy: 'bg-n-amber-10',
  offline: 'bg-n-slate-10',
});
export const DEFAULT_PRESENCE = 'offline';

// conversation_load as the assignable agents and agents lists send it: open, pending and
// snoozed conversations assigned to the agent, against their limit (CDP spec §7.1, §15).
export const formatAgentLoad = load =>
  load ? `${load.assigned_count}/${load.limit}` : '';

export const isAgentAtLimit = load =>
  Boolean(load) && load.assigned_count >= load.limit;

// The agents store follows presence events live; the assignable agents payload is a
// snapshot from when the list was fetched.
export const withLivePresence = (agents, liveAgents) => {
  const presenceById = Object.fromEntries(
    liveAgents.map(agent => [agent.id, agent.availability_status])
  );
  return agents.map(agent => ({
    ...agent,
    availability_status:
      presenceById[agent.id] || agent.availability_status || DEFAULT_PRESENCE,
  }));
};

/**
 * The Assign dialog's rows: agents matching the search, online first, then busy, then
 * offline, each with the names of the project teams they are in.
 * @param {Object} params
 * @param {Array} params.agents - The assignable agents of the conversation's inbox
 * @param {Array} params.liveAgents - The agents store, for live presence
 * @param {Object} params.currentUser - Their own presence is read from their account
 * @param {number} params.accountId
 * @param {Array} params.teams - The project's teams
 * @param {Object} params.teamIdsByAgent - { agentId: [teamId] }
 * @param {string} params.query - The search box
 */
export const buildAssignRows = ({
  agents,
  liveAgents,
  currentUser,
  accountId,
  teams,
  teamIdsByAgent,
  query,
}) => {
  const trimmedQuery = query.trim();
  const searched = trimmedQuery
    ? picoSearch(agents, trimmedQuery, ['name', 'available_name', 'email'])
    : agents;
  const withPresence = getAgentsByUpdatedPresence(
    withLivePresence(searched, liveAgents),
    currentUser,
    accountId
  );

  return getSortedAgentsByAvailability(withPresence).map(agent => ({
    ...agent,
    teamNames: teams
      .filter(team => (teamIdsByAgent[agent.id] ?? []).includes(team.id))
      .map(team => team.name),
  }));
};
