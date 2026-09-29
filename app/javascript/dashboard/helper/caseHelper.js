// Colours from components-next/label/Label.vue: P1 red, P2 amber, P3 blue (iris is the On Hold
// chip's tone, and Label has no dark tone for the spec's black), P4 grey (spec 9.2)
export const CASE_SEVERITY_COLORS = Object.freeze({
  p1: 'ruby',
  p2: 'amber',
  p3: 'blue',
  p4: 'slate',
});

// A case's status is its conversation's status
export const CASE_STATUS_COLORS = Object.freeze({
  open: 'blue',
  pending: 'amber',
  snoozed: 'iris',
  resolved: 'teal',
  closed: 'slate',
});

// Solved and Closed: the case is no longer being worked on
export const CASE_FINISHED_STATUSES = Object.freeze(['resolved', 'closed']);

export const CASE_TABS = Object.freeze({ ALL: 'all', MINE: 'mine' });

export const caseSeverityColor = severity =>
  CASE_SEVERITY_COLORS[severity] || CASE_SEVERITY_COLORS.p4;

export const caseStatusColor = status =>
  CASE_STATUS_COLORS[status] || CASE_STATUS_COLORS.closed;

// All, one tab per team (the case "inbox"), then My Cases
export const buildCaseTabs = (teams = []) => [
  { key: CASE_TABS.ALL },
  ...teams.map(team => ({
    key: `team-${team.id}`,
    teamId: team.id,
    label: team.name,
  })),
  { key: CASE_TABS.MINE },
];

export const caseTabParams = tab => {
  if (tab?.teamId) return { team_id: tab.teamId };
  if (tab?.key === CASE_TABS.MINE) return { mine: true };
  return {};
};
