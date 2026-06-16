function assertString(value, field) {
  if (typeof value !== 'string' || value.length === 0) {
    const err = new Error(`'${field}' must be a non-empty string`);
    err.statusCode = 400;
    err.details = { field };
    throw err;
  }
}

function assertNumberInRange(value, field, min, max) {
  if (typeof value !== 'number' || Number.isNaN(value)) {
    const err = new Error(`'${field}' must be a number`);
    err.statusCode = 400;
    err.details = { field };
    throw err;
  }
  if (value < min || value > max) {
    const err = new Error(`'${field}' must be between ${min} and ${max}`);
    err.statusCode = 400;
    err.details = { field };
    throw err;
  }
}

function validateDiscoveryRequest(body) {
  if (!body || typeof body !== 'object') {
    const err = new Error('Request body must be a JSON object');
    err.statusCode = 400;
    throw err;
  }

  assertString(body.artifact_id, 'artifact_id');
  assertString(body.fragment_id, 'fragment_id');
  assertString(body.player_id, 'player_id');
  assertString(body.timestamp, 'timestamp');
  assertNumberInRange(body.condition, 'condition', 0, 100);

  if (typeof body.discovery_context !== 'string') {
    body.discovery_context = '';
  }

  const isoRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;
  if (!isoRegex.test(body.timestamp)) {
    const err = new Error("'timestamp' must be a valid ISO-8601 string");
    err.statusCode = 400;
    err.details = { field: 'timestamp' };
    throw err;
  }

  return body;
}

module.exports = { validateDiscoveryRequest };
