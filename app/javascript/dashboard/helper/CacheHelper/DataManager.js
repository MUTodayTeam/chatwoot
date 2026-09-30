import { openDB } from 'idb';
import { DATA_VERSION, INBOX_CACHE_INVALIDATION_VERSION } from './version';

// How long to wait for the cache before reading from the network instead
export const CACHE_OPEN_TIMEOUT_MS = 3000;

export class DataManager {
  constructor(accountId) {
    this.modelsToSync = ['inbox', 'label', 'team', 'canned_response'];
    this.accountId = accountId;
    this.db = null;
  }

  async initDb() {
    if (this.db) return this.db;
    const dbName = `cw-store-${this.accountId}`;
    // A tab still running the previous build keeps the old version open, and an upgrade waits
    // for it to close, which can be forever. A request queued behind another tab's pending
    // upgrade never even gets a blocked event. Give up on the cache in both cases, so the
    // caller reads from the network instead of hanging on "loading inboxes".
    let rejectBlocked;
    let timeout;
    const blocked = new Promise((_resolve, reject) => {
      rejectBlocked = reject;
      timeout = setTimeout(
        () => reject(new Error('IndexedDB did not open in time')),
        CACHE_OPEN_TIMEOUT_MS
      );
    });
    const opening = openDB(dbName, DATA_VERSION, {
      blocked: () =>
        rejectBlocked(new Error('IndexedDB upgrade blocked by another tab')),
      // A newer build wants to upgrade: close this connection so it is not the one blocking it.
      blocking: () => {
        this.db?.close();
        this.db = null;
      },
      upgrade(db, oldVersion, _newVersion, transaction) {
        const shouldInvalidateInboxCache =
          oldVersion > 0 && oldVersion < INBOX_CACHE_INVALIDATION_VERSION;

        if (shouldInvalidateInboxCache) {
          transaction.objectStore('inbox').clear();
          transaction.objectStore('cache-keys').delete('inbox');
        }

        // Existing databases already carry the stores added in earlier versions,
        // and createObjectStore throws on a name that is already taken.
        const createStore = (name, options) => {
          if (db.objectStoreNames.contains(name)) return;
          db.createObjectStore(name, options);
        };

        createStore('cache-keys');
        createStore('inbox', { keyPath: 'id' });
        createStore('label', { keyPath: 'id' });
        createStore('team', { keyPath: 'id' });
        createStore('canned_response', { keyPath: 'id' });
      },
    });
    // Once the other tab lets go, the upgraded connection serves later reads.
    opening.then(
      db => {
        this.db = this.db || db;
      },
      () => {}
    );
    try {
      this.db = await Promise.race([opening, blocked]);
    } finally {
      clearTimeout(timeout);
    }

    // Store the database name in LocalStorage
    const dbNames = JSON.parse(localStorage.getItem('cw-idb-names') || '[]');
    if (!dbNames.includes(dbName)) {
      dbNames.push(dbName);
      localStorage.setItem('cw-idb-names', JSON.stringify(dbNames));
    }

    return this.db;
  }

  validateModel(name) {
    if (!name) throw new Error('Model name is not defined');
    if (!this.modelsToSync.includes(name)) {
      throw new Error(`Model ${name} is not defined`);
    }
    return true;
  }

  async replace({ modelName, data }) {
    this.validateModel(modelName);

    await this.db.clear(modelName);
    return this.push({ modelName, data });
  }

  async push({ modelName, data }) {
    this.validateModel(modelName);

    if (Array.isArray(data)) {
      const tx = this.db.transaction(modelName, 'readwrite');
      data.forEach(item => {
        tx.store.add(item);
      });
      await tx.done;
    } else {
      await this.db.add(modelName, data);
    }
  }

  async get({ modelName }) {
    this.validateModel(modelName);
    return this.db.getAll(modelName);
  }

  async setCacheKeys(cacheKeys) {
    Object.keys(cacheKeys).forEach(async modelName => {
      this.db.put('cache-keys', cacheKeys[modelName], modelName);
    });
  }

  async getCacheKey(modelName) {
    this.validateModel(modelName);

    return this.db.get('cache-keys', modelName);
  }
}
