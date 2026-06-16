/**
 * Manual validators for scan and portal requests.
 *
 * We avoid a heavy validation library to keep the backend lightweight.
 * Each validator throws an error with statusCode/details on failure.
 */

const HIDDEN_TRUTH_FIELDS = new Set([
  'is_carrier',
  'fragment_id',
  'contents',
  'is_counterfeit_truth',
]);

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

function validateScanRequest(body) {
  if (!body || typeof body !== 'object') {
    const err = new Error('Request body must be a JSON object');
    err.statusCode = 400;
    throw err;
  }

  for (const field of HIDDEN_TRUTH_FIELDS) {
    if (field in body) {
      const err = new Error(`Request must not contain hidden truth field '${field}'`);
      err.statusCode = 400;
      err.details = { field };
      throw err;
    }
  }

  assertString(body.template_id, 'template_id');
  if ('condition' in body) {
    assertNumberInRange(body.condition, 'condition', 0, 100);
  }

  return body;
}

function validatePortalRequest(body) {
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

  // Validate ISO-8601 shape loosely.
  const isoRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;
  if (!isoRegex.test(body.timestamp)) {
    const err = new Error("'timestamp' must be a valid ISO-8601 string");
    err.statusCode = 400;
    err.details = { field: 'timestamp' };
    throw err;
  }

  return body;
}

module.exports = {
  validateScanRequest,
  validatePortalRequest,
};
