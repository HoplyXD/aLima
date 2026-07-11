const request = require('supertest');
const http = require('http');
const createApp = require('../src/app');
const { resetCache } = require('../src/services/museum_service');
const { initApp } = require('../../mock-portal/src/app');
const db = require('../../mock-portal/src/db');

const app = createApp();

const GOLD_RECORD = {
  record_id: 'oton_death_mask',
  player_id: 'local-player',
  rarity: 'gold',
  timestamp: '2026-07-11T12:00:00Z',
  condition: 95,
  discovery_context: 'preserved from shop inventory',
  display_name: 'Oton Death Mask',
};

const MASTER_RECORD = {
  record_id: 'master_artifact_demo',
  player_id: 'local-player',
  rarity: 'master_artifact',
  timestamp: '2026-07-11T12:00:00Z',
  condition: 100,
  discovery_context: 'assembled from five seated fragments',
  display_name: 'Heirloom Timepiece (placeholder)',
};

describe('POST /api/portal/museum', () => {
  let portalServer;
  let portalPort;
  let originalPortalBaseUrl;
  let originalPortalTimeout;
  let originalPortalApiKey;

  beforeAll(async () => {
    originalPortalBaseUrl = process.env.PORTAL_BASE_URL;
    originalPortalTimeout = process.env.PORTAL_TIMEOUT_MS;
    originalPortalApiKey = process.env.PORTAL_API_KEY;
    process.env.PORTAL_API_KEY = '';

    const mockPortal = await initApp();
    portalServer = http.createServer(mockPortal);
    await new Promise((resolve) => {
      portalServer.listen(0, '127.0.0.1', () => {
        portalPort = portalServer.address().port;
        resolve();
      });
    });
  });

  afterAll((done) => {
    process.env.PORTAL_BASE_URL = originalPortalBaseUrl;
    process.env.PORTAL_TIMEOUT_MS = originalPortalTimeout;
    process.env.PORTAL_API_KEY = originalPortalApiKey;
    db.close().then(() => {
      if (portalServer) {
        if (typeof portalServer.closeAllConnections === 'function') {
          portalServer.closeAllConnections();
        }
        portalServer.close(done);
      } else {
        done();
      }
    });
  });

  beforeEach(() => {
    resetCache();
    process.env.PORTAL_BASE_URL = `http://127.0.0.1:${portalPort}`;
    process.env.PORTAL_TIMEOUT_MS = '5000';
  });

  test('valid Gold record returns mock Portal museum record', async () => {
    const res = await request(app).post('/api/portal/museum').send(GOLD_RECORD);

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.museum_entry_id).toBe('entry_oton_death_mask_local-player');
    expect(res.body.record_id).toBe('oton_death_mask');
    expect(res.body.record_type).toBe('museum_discovery');
    expect(typeof res.body.fact_card).toBe('string');
    expect(res.body.fact_card.length).toBeGreaterThan(0);
    expect(res.body.used_fallback).toBe(false);
  });

  test('valid Master Artifact record returns assembled-artifact type', async () => {
    const res = await request(app).post('/api/portal/museum').send(MASTER_RECORD);

    expect(res.statusCode).toBe(200);
    expect(res.body.record_type).toBe('assembled_artifact');
    expect(res.body.museum_entry_id).toBe('entry_master_artifact_demo_local-player');
    expect(res.body.used_fallback).toBe(false);
  });

  test('invalid payload returns 400', async () => {
    const res = await request(app).post('/api/portal/museum').send({ record_id: 'x' });

    expect(res.statusCode).toBe(400);
    expect(res.body.ok).toBe(false);
  });

  test('duplicate record returns same museum_entry_id', async () => {
    const first = await request(app).post('/api/portal/museum').send(GOLD_RECORD);
    const second = await request(app).post('/api/portal/museum').send(GOLD_RECORD);

    expect(first.statusCode).toBe(200);
    expect(second.statusCode).toBe(200);
    expect(second.body.museum_entry_id).toBe(first.body.museum_entry_id);
    expect(second.body.fact_card).toBe(first.body.fact_card);
  });
});

describe('Museum retrieval (PORT-R6)', () => {
  let portalServer;
  let portalPort;
  let originalPortalBaseUrl;
  let originalPortalTimeout;
  let originalPortalApiKey;

  beforeAll(async () => {
    originalPortalBaseUrl = process.env.PORTAL_BASE_URL;
    originalPortalTimeout = process.env.PORTAL_TIMEOUT_MS;
    originalPortalApiKey = process.env.PORTAL_API_KEY;
    process.env.PORTAL_API_KEY = '';

    const mockPortal = await initApp();
    portalServer = http.createServer(mockPortal);
    await new Promise((resolve) => {
      portalServer.listen(0, '127.0.0.1', () => {
        portalPort = portalServer.address().port;
        resolve();
      });
    });
  });

  afterAll((done) => {
    process.env.PORTAL_BASE_URL = originalPortalBaseUrl;
    process.env.PORTAL_TIMEOUT_MS = originalPortalTimeout;
    process.env.PORTAL_API_KEY = originalPortalApiKey;
    db.close().then(() => {
      if (portalServer) {
        if (typeof portalServer.closeAllConnections === 'function') {
          portalServer.closeAllConnections();
        }
        portalServer.close(done);
      } else {
        done();
      }
    });
  });

  beforeEach(() => {
    resetCache();
    process.env.PORTAL_BASE_URL = `http://127.0.0.1:${portalPort}`;
    process.env.PORTAL_TIMEOUT_MS = '5000';
  });

  test('GET list returns records from mock Portal', async () => {
    await request(app).post('/api/portal/museum').send(GOLD_RECORD);

    const res = await request(app)
      .get('/api/portal/museum')
      .query({ player_id: 'local-player' });

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.used_fallback).toBe(false);
    expect(Array.isArray(res.body.entries)).toBe(true);
    const ids = res.body.entries.map((e) => e.museum_entry_id);
    expect(ids).toContain('entry_oton_death_mask_local-player');
  });

  test('GET by id returns a known record from mock Portal', async () => {
    await request(app).post('/api/portal/museum').send(GOLD_RECORD);

    const res = await request(app)
      .get('/api/portal/museum/entry_oton_death_mask_local-player')
      .query({ player_id: 'local-player' });

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.record_id).toBe('oton_death_mask');
  });

  test('GET by id for unknown record returns 404', async () => {
    const res = await request(app)
      .get('/api/portal/museum/entry_no_such_id_local-player')
      .query({ player_id: 'local-player' });

    expect(res.statusCode).toBe(404);
    expect(res.body.ok).toBe(false);
  });
});

describe('Museum fallback (offline mirror)', () => {
  let proxyServer;

  beforeEach(() => {
    resetCache();
  });

  afterEach((done) => {
    if (proxyServer) {
      if (typeof proxyServer.closeAllConnections === 'function') {
        proxyServer.closeAllConnections();
      }
      proxyServer.close(done);
      proxyServer = null;
    } else {
      done();
    }
  });

  test('POST falls back to cached record when Portal is unreachable', async () => {
    const express = require('express');
    const slowPortal = express();
    slowPortal.post('/museum', (_req, res) => {
      setTimeout(() => res.sendStatus(200), 60000);
    });

    proxyServer = http.createServer(slowPortal);
    await new Promise((resolve) => {
      proxyServer.listen(0, '127.0.0.1', () => {
        const port = proxyServer.address().port;
        process.env.PORTAL_BASE_URL = `http://127.0.0.1:${port}`;
        process.env.PORTAL_TIMEOUT_MS = '50';
        resolve();
      });
    });

    const testApp = createApp();
    const res = await request(testApp).post('/api/portal/museum').send(GOLD_RECORD);

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.used_fallback).toBe(true);
    expect(res.body.museum_entry_id).toBe('entry_oton_death_mask_local-player');
  });

  test('GET list returns cached records when Portal is down', async () => {
    // Seed the server-side cache by posting through a working proxy first.
    const working = await initApp();
    proxyServer = http.createServer(working);
    await new Promise((resolve) => {
      proxyServer.listen(0, '127.0.0.1', () => {
        const port = proxyServer.address().port;
        process.env.PORTAL_BASE_URL = `http://127.0.0.1:${port}`;
        process.env.PORTAL_TIMEOUT_MS = '5000';
        resolve();
      });
    });

    let testApp = createApp();
    await request(testApp).post('/api/portal/museum').send(GOLD_RECORD);

    // Now point at a dead port and list: cached entry should still come back.
    process.env.PORTAL_BASE_URL = 'http://127.0.0.1:1';
    process.env.PORTAL_TIMEOUT_MS = '50';
    testApp = createApp();

    const res = await request(testApp)
      .get('/api/portal/museum')
      .query({ player_id: 'local-player' });

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.used_fallback).toBe(true);
    const ids = res.body.entries.map((e) => e.museum_entry_id);
    expect(ids).toContain('entry_oton_death_mask_local-player');
  });

  test('malformed upstream response returns fallback', async () => {
    const express = require('express');
    const badPortal = express();
    badPortal.post('/museum', (_req, res) => {
      res.setHeader('Content-Type', 'application/json');
      res.status(200).send('not valid json');
    });

    proxyServer = http.createServer(badPortal);
    await new Promise((resolve) => {
      proxyServer.listen(0, '127.0.0.1', () => {
        const port = proxyServer.address().port;
        process.env.PORTAL_BASE_URL = `http://127.0.0.1:${port}`;
        process.env.PORTAL_TIMEOUT_MS = '5000';
        resolve();
      });
    });

    const testApp = createApp();
    const res = await request(testApp).post('/api/portal/museum').send(MASTER_RECORD);

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.used_fallback).toBe(true);
  });
});

describe('Museum Portal API key', () => {
  let portalServer;
  let portalPort;
  let originalPortalBaseUrl;
  let originalPortalTimeout;
  let originalPortalApiKey;
  const TEST_KEY = 'video-demo-key';

  beforeAll(async () => {
    originalPortalBaseUrl = process.env.PORTAL_BASE_URL;
    originalPortalTimeout = process.env.PORTAL_TIMEOUT_MS;
    originalPortalApiKey = process.env.PORTAL_API_KEY;
    process.env.PORTAL_API_KEY = TEST_KEY;

    const mockPortal = await initApp();
    portalServer = http.createServer(mockPortal);
    await new Promise((resolve) => {
      portalServer.listen(0, '127.0.0.1', () => {
        portalPort = portalServer.address().port;
        resolve();
      });
    });
  });

  afterAll((done) => {
    process.env.PORTAL_BASE_URL = originalPortalBaseUrl;
    process.env.PORTAL_TIMEOUT_MS = originalPortalTimeout;
    process.env.PORTAL_API_KEY = originalPortalApiKey;
    db.close().then(() => {
      if (portalServer) {
        if (typeof portalServer.closeAllConnections === 'function') {
          portalServer.closeAllConnections();
        }
        portalServer.close(done);
      } else {
        done();
      }
    });
  });

  beforeEach(() => {
    resetCache();
    process.env.PORTAL_BASE_URL = `http://127.0.0.1:${portalPort}`;
    process.env.PORTAL_TIMEOUT_MS = '5000';
    process.env.PORTAL_API_KEY = TEST_KEY;
  });

  test('backend sends API key and Portal accepts the request', async () => {
    const res = await request(app).post('/api/portal/museum').send(GOLD_RECORD);

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.used_fallback).toBe(false);
  });

  test('wrong API key causes fallback response', async () => {
    process.env.PORTAL_API_KEY = 'wrong-key';

    const testApp = createApp();
    const res = await request(testApp).post('/api/portal/museum').send({
      ...GOLD_RECORD,
      record_id: 'oton_death_mask_key_test',
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.used_fallback).toBe(true);
  });
});
