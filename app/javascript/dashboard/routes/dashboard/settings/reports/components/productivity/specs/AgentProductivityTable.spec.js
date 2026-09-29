import { mount } from '@vue/test-utils';
import AgentProductivityTable from '../AgentProductivityTable.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
    locale: { value: 'en' },
  }),
}));

// Spec 10: Toon escalated a general handover to Poy, who solved it
const agents = [
  {
    id: 2,
    name: 'Poy',
    resolved: 1,
    assisted: 0,
    transferOut: 0,
    transferIn: 1,
    penalty: 0,
    contributionPercent: 100,
    avgHandleTime: 480,
    avgFirstResponse: null,
    score: 1,
  },
  {
    id: 1,
    name: 'Toon',
    resolved: 0,
    assisted: 1,
    transferOut: 1,
    transferIn: 0,
    penalty: 0.2,
    contributionPercent: 0,
    avgHandleTime: 720,
    avgFirstResponse: 120,
    score: 0.3,
  },
];

const cellsOf = row => row.findAll('th, td').map(cell => cell.text());

describe('AgentProductivityTable.vue', () => {
  it('lists each agent with their credit, times and score', () => {
    const rows = mount(AgentProductivityTable, { props: { agents } }).findAll(
      'tbody tr'
    );

    expect(cellsOf(rows[0])).toEqual([
      'Poy',
      '1',
      '0',
      '0',
      '1',
      '',
      '00:08:00',
      '—',
      '1.0',
    ]);
    expect(cellsOf(rows[1])[3]).toBe(
      '1 OVERVIEW_REPORTS.AGENT_PRODUCTIVITY.PENALTY {"penalty":"0.2"}'
    );
    expect(cellsOf(rows[1]).slice(6)).toEqual(['00:12:00', '00:02:00', '0.3']);
  });

  it('splits the contribution bar into resolved and assisted', () => {
    const bars = mount(AgentProductivityTable, {
      props: { agents: [{ ...agents[0], contributionPercent: 25 }] },
    }).find('[role="img"]');

    expect(bars.findAll('div')[0].attributes('style')).toContain('width: 25%');
    expect(bars.attributes('aria-label')).toContain('"resolved":25');
    expect(bars.attributes('aria-label')).toContain('"assisted":75');
  });

  it('says so when nothing was solved in the range', () => {
    const wrapper = mount(AgentProductivityTable, { props: { agents: [] } });

    expect(wrapper.find('tbody').text()).toBe(
      'OVERVIEW_REPORTS.AGENT_PRODUCTIVITY.NO_AGENTS'
    );
  });
});
