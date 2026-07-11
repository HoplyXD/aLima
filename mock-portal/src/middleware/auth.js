function createRequireApiKey(expectedKey) {
  return function requireApiKey(req, res, next) {
    if (!expectedKey) {
      next();
      return;
    }

    const authHeader = req.headers.authorization || '';
    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer' || parts[1] !== expectedKey) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    next();
  };
}

module.exports = { createRequireApiKey };
