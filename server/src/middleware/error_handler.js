/**
 * Centralized JSON error handler.
 *
 * Returns structured errors without leaking stack traces in production.
 */
function errorHandler(err, _req, res, _next) {
  const statusCode = err.statusCode || err.status || 500;
  const message = err.message || 'Internal server error';
  const response = {
    ok: false,
    error: message,
  };
  if (err.details) {
    response.details = err.details;
  }
  res.status(statusCode).json(response);
}

module.exports = errorHandler;
