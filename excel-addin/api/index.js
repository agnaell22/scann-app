const { randomUUID } = require('crypto');

// In-memory pairings store across lambda warm invocations
const pairings = global.__BRIDGESHEET_PAIRINGS__ || new Map();
global.__BRIDGESHEET_PAIRINGS__ = pairings;

module.exports = async (req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  const url = req.url || '/';

  // POST /v1/pairings
  if (req.method === 'POST' && (url === '/v1/pairings' || url === '/api/v1/pairings')) {
    const pairingId = `live_${randomUUID()}`;
    pairings.set(pairingId, { value: null, createdAt: Date.now() });
    
    return res.status(200).json({
      pairingId,
      qrPayload: `bridgesheet://pair?token=${pairingId}`,
    });
  }

  // GET /v1/pairings/:id/inbox
  const inboxMatch = url.match(/^\/(?:api\/)?v1\/pairings\/([^/]+)\/inbox$/);
  if (req.method === 'GET' && inboxMatch) {
    const pairingId = decodeURIComponent(inboxMatch[1]);
    const pairing = pairings.get(pairingId);
    
    if (!pairing) {
      return res.status(404).json({ error: 'Pairing session not found or expired' });
    }
    
    if (!pairing.value) {
      return res.status(204).end();
    }

    const value = pairing.value;
    pairing.value = null; // Clear item once consumed
    return res.status(200).json({ value, receivedAt: new Date().toISOString() });
  }

  // POST /v1/values or POST /v1/test-value
  if (req.method === 'POST' && (url === '/v1/values' || url === '/v1/test-value' || url === '/api/v1/values')) {
    const body = req.body || {};
    const pairingId = body.pairingId || body.token;
    
    if (!pairingId) {
      return res.status(400).json({ error: 'Missing pairingId or token' });
    }

    const pairing = pairings.get(pairingId);
    if (!pairing) {
      return res.status(404).json({ error: `Pairing session not found: ${pairingId}` });
    }

    pairing.value = String(body.value ?? '');
    return res.status(202).json({ accepted: true, value: pairing.value });
  }

  return res.status(404).json({ error: 'Endpoint not found' });
};
