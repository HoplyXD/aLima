const request = require('supertest');
const http = require('http');
const createApp = require('../src/app');
const { resetCache } = require('../src/services/portal_service');
const createMockPortal = require('../../mock-portal/src/app');

const app = createApp();

describe('POST /api/portal/discovery', () => {
  let portalServer;
  let portalPort;
  let originalPortalBaseUrl;
  let originalPortalTimeout;

  beforeAll(async () => {
    originalPortalBaseUrl = process.env.PORTAL_BASE_URL;
    originalPortalTimeout = process.env.PORTAL_TIMEOUT_MS;

    const mockPortal = createMockPortal();
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
    if (portalServer) {
      if (typeof portalServer.closeAllConnections === 'function') {
        portalServer.closeAllConnections();
      }
      portalServer.close(done);
    } else {
      done();
    }
  });

  beforeEach(() => {
    resetCache();
    process.env.PORTAL_BASE_URL = `http://127.0.0.1:${portalPort}`;
    process.env.PORTAL_TIMEOUT_MS = '5000';
  });

  test('valid discovery returns mock Portal fact card', async () => {
    const res = await request(app)
      .post('/api/portal/discovery')
      .send({
        artifact_id: 'master_artifact_demo',
        fragment_id: 'fragment_01',
        player_id: 'local-player',
        timestamp: '2026-06-16T22:46:58Z',
        condition: 100,
        discovery_context: 'opened from tarnished_pendant',
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.museum_entry_id).toBe('entry_fragment_01_local-player');
    expect(res.body.fragment_index).toBe(1);
    expect(typeof res.body.fact_card).toBe('string');
    expect(res.body.fact_card.length).toBeGreaterThan(0);
    expect(res.body.artifact_meta).toMatchObject({
      name: expect.any(String),
      period: expect.any(String),
      origin: expect.any(String),
    });
    expect(res.body.used_fallback).toBe(false);
  });

  test('invalid payload returns 400', async () => {
    const res = await request(app)
      .post('/api/portal/discovery')
      .send({ fragment_id: 'fragment_01' });

    expect(res.statusCode).toBe(400);
    expect(res.body.ok).toBe(false);
  });

  test('duplicate request returns same museum_entry_id', async () => {
    const body = {
      artifact_id: 'master_artifact_demo',
      fragment_id: 'fragment_01',
      player_id: 'local-player',
      timestamp: '2026-06-16T22:46:58Z',
      condition: 100,
      discovery_context: 'opened from tarnished_pendant',
    };

    const first = await request(app).post('/api/portal/discovery').send(body);
    const second = await request(app).post('/api/portal/discovery').send(body);

    expect(first.statusCode).toBe(200);
    expect(second.statusCode).toBe(200);
    expect(second.body.museum_entry_id).toBe(first.body.museum_entry_id);
    expect(second.body.fact_card).toBe(first.body.fact_card);
    expect(second.body.used_fallback).toBe(false);
  });

  test('bad timestamp returns 400', async () => {
    const res = await request(app)
      .post('/api/portal/discovery')
      .send({
        artifact_id: 'master_artifact_demo',
        fragment_id: 'fragment_01',
        player_id: 'local-player',
        timestamp: 'not-a-date',
        condition: 100,
      });

    expect(res.statusCode).toBe(400);
    expect(res.body.ok).toBe(false);
  });
});

describe('Portal fallback', () => {
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

  test('timeout returns used_fallback true', async () => {
    const express = require('express');
    const slowPortal = express();
    slowPortal.post('/discovery', (_req, res) => {
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
    const res = await request(testApp)
      .post('/api/portal/discovery')
      .send({
        artifact_id: 'master_artifact_demo',
        fragment_id: 'fragment_02',
        player_id: 'local-player',
        timestamp: '2026-06-16T22:46:58Z',
        condition: 90,
        discovery_context: 'timeout test',
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.used_fallback).toBe(true);
    expect(res.body.museum_entry_id).toBe('entry_fragment_02_local-player');
    expect(typeof res.body.fact_card).toBe('string');
  });

  test('malformed upstream response returns fallback', async () => {
    const express = require('express');
    const badPortal = express();
    badPortal.post('/discovery', (_req, res) => {
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
    const res = await request(testApp)
      .post('/api/portal/discovery')
      .send({
        artifact_id: 'master_artifact_demo',
        fragment_id: 'fragment_04',
        player_id: 'local-player',
        timestamp: '2026-06-16T22:46:58Z',
        condition: 95,
        discovery_context: 'malformed test',
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.used_fallback).toBe(true);
  });
});
