const express = require('express');
const scanRoutes = require('./routes/scan');
const portalRoutes = require('./routes/portal');
const negotiateRoutes = require('./routes/negotiate');
const errorHandler = require('./middleware/error_handler');

function createApp() {
  const app = express();

  app.use(express.json({ limit: '16kb' }));

  app.use('/api/scan', scanRoutes);
  app.use('/api/portal', portalRoutes);
  app.use('/api/negotiate', negotiateRoutes);

  // Health check for orchestration/tests.
  app.get('/health', (_req, res) => {
    res.status(200).json({ ok: true, service: 'alima-server' });
  });

  app.use((_req, res) => {
    res.status(404).json({ ok: false, error: 'Not found' });
  });

  app.use(errorHandler);

  return app;
}

module.exports = createApp;
