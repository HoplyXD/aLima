const config = require('./config');
const createApp = require('./app');

const app = createApp();

app.listen(config.port, () => {
  // eslint-disable-next-line no-console
  console.log(`aLima mock portal listening on port ${config.port}`);
});
