const config = require('./config');
const createApp = require('./app');

const app = createApp();

app.listen(config.port, () => {
  // eslint-disable-next-line no-console
  console.log(`aLima server listening on port ${config.port}`);
});
