import {
  buildCaseTabs,
  caseSeverityColor,
  caseStatusColor,
  caseTabParams,
  CASE_TABS,
} from '../caseHelper';

describe('caseHelper', () => {
  describe('buildCaseTabs', () => {
    it('puts one tab per team between All and My Cases', () => {
      const tabs = buildCaseTabs([
        { id: 3, name: 'CRM' },
        { id: 5, name: 'Dev' },
      ]);

      expect(tabs).toEqual([
        { key: CASE_TABS.ALL },
        { key: 'team-3', teamId: 3, label: 'CRM' },
        { key: 'team-5', teamId: 5, label: 'Dev' },
        { key: CASE_TABS.MINE },
      ]);
    });

    it('keeps All and My Cases without teams', () => {
      expect(buildCaseTabs().map(tab => tab.key)).toEqual([
        CASE_TABS.ALL,
        CASE_TABS.MINE,
      ]);
    });
  });

  describe('caseTabParams', () => {
    it('filters a team tab by its team', () => {
      expect(caseTabParams({ key: 'team-3', teamId: 3 })).toEqual({
        team_id: 3,
      });
    });

    it('asks for my cases on My Cases', () => {
      expect(caseTabParams({ key: CASE_TABS.MINE })).toEqual({ mine: true });
    });

    it('sends no filter on All', () => {
      expect(caseTabParams({ key: CASE_TABS.ALL })).toEqual({});
      expect(caseTabParams(undefined)).toEqual({});
    });
  });

  describe('colours', () => {
    it('maps severities and falls back to low', () => {
      expect(caseSeverityColor('p1')).toBe('ruby');
      expect(caseSeverityColor('p2')).toBe('amber');
      expect(caseSeverityColor('p3')).toBe('blue');
      expect(caseSeverityColor('p4')).toBe('slate');
      expect(caseSeverityColor('unknown')).toBe('slate');
    });

    it('maps conversation statuses', () => {
      expect(caseStatusColor('open')).toBe('blue');
      expect(caseStatusColor('resolved')).toBe('teal');
      expect(caseStatusColor('closed')).toBe('slate');
      expect(caseStatusColor('unknown')).toBe('slate');
    });
  });
});
