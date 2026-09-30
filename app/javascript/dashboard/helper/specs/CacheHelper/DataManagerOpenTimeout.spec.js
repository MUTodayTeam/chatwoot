import { openDB } from 'idb';
import {
  CACHE_OPEN_TIMEOUT_MS,
  DataManager,
} from '../../CacheHelper/DataManager';

// Chrome queues an open request behind another tab's pending upgrade without firing
// blocked on it, so the request simply never settles.
vi.mock('idb', () => ({ openDB: vi.fn(() => new Promise(() => {})) }));

describe('DataManager when IndexedDB never opens', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('gives up after the open timeout so the caller can read from the network', async () => {
    const opening = new DataManager('queued-account').initDb();
    const outcome = expect(opening).rejects.toThrow('did not open in time');

    await vi.advanceTimersByTimeAsync(CACHE_OPEN_TIMEOUT_MS);

    await outcome;
    expect(openDB).toHaveBeenCalledTimes(1);
  });
});
