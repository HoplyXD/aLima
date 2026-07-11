const path = require('path');
const express = require('express');
const discoveryRoutes = require('./routes/discovery');
const museumRoutes = require('./routes/museum');
const errorHandler = require('./middleware/error_handler');
const { createRequireApiKey } = require('./middleware/auth');
const config = require('./config');
const db = require('./db');

function createApp() {
  const app = express();

  app.use(express.json({ limit: '16kb' }));
  app.use(express.static(path.join(__dirname, '..', 'public')));

  const expectedKey = config.portalApiKey;
  app.use(createRequireApiKey(expectedKey));

  app.use('/discovery', discoveryRoutes);
  app.use('/museum', museumRoutes);

  app.get('/health', (_req, res) => {
    res.status(200).json({ ok: true, service: 'alima-mock-portal' });
  });

  app.get('/', (_req, res) => {
    res.sendFile(path.join(__dirname, '..', 'public', 'gallery.html'));
  });

  app.use((_req, res) => {
    res.status(404).json({ ok: false, error: 'Not found' });
  });

  app.use(errorHandler);

  return app;
}

async function initApp() {
  await db.init();
  return createApp();
}

module.exports = { createApp, initApp };
