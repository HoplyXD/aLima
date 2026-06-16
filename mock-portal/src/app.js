const express = require('express');
const discoveryRoutes = require('./routes/discovery');
const errorHandler = require('./middleware/error_handler');

function createApp() {
  const app = express();

  app.use(express.json({ limit: '16kb' }));

  app.use('/discovery', discoveryRoutes);

  app.get('/health', (_req, res) => {
    res.status(200).json({ ok: true, service: 'alima-mock-portal' });
  });

  app.use((_req, res) => {
    res.status(404).json({ ok: false, error: 'Not found' });
  });

  app.use(errorHandler);

  return app;
}

module.exports = createApp;
