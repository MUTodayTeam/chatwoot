// Row 1 of the conversation header (CDP spec §5): the channel and project tags sit next to
// the contact's name on wide screens and fold into the subtitle below 1320px, which
// always ends with who has the conversation.
export const getHeaderTags = ({ inbox, project }) =>
  [
    inbox?.name && { key: 'channel', label: inbox.name },
    project?.name && { key: 'project', label: project.name },
  ].filter(Boolean);

export const getAssigneeName = assignee =>
  assignee?.available_name || assignee?.name || '';
