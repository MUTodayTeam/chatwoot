import { cannedResponsesForProject } from '../cannedResponseHelper';

const shared = { id: 1, short_code: 'thanks', project_id: null };
const checkin = { id: 2, short_code: 'checkin', project_id: 7 };
const share = { id: 3, short_code: 'share', project_id: 8 };
// Cached before the project_id column existed
const legacy = { id: 4, short_code: 'hello' };
const responses = [shared, checkin, share, legacy];

describe('cannedResponsesForProject', () => {
  it("keeps the project's responses and the shared ones", () => {
    expect(cannedResponsesForProject(responses, 7)).toEqual([
      shared,
      checkin,
      legacy,
    ]);
  });

  it('keeps only the shared responses for an inbox outside every project', () => {
    expect(cannedResponsesForProject(responses, null)).toEqual([
      shared,
      legacy,
    ]);
  });
});
