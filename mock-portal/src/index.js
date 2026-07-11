const config = require('./config');
const { initApp } = require('./app');

initApp()
  .then((app) => {
    app.listen(config.port, () => {
      // eslint-disable-next-line no-console
      console.log(`aLima mock portal listening on port ${config.port}`);
    });
  })
  .catch((err) => {
    // eslint-disable-next-line no-console
    console.error('Failed to start mock portal:', err);
    process.exit(1);
  });
