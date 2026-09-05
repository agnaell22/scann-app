const http = require('http');
const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');

const root = __dirname;
const port = 3000;
const pairings = new Map();
const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.png': 'image/png',
};

function sendJson(response, status, value) {
  response.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  });
  response.end(JSON.stringify(value));
}

function body(request) {
  return new Promise((resolve, reject) => {
    let content = '';
    request.on('data', (chunk) => { content += chunk; });
    request.on('end', () => resolve(content ? JSON.parse(content) : {}));
    request.on('error', reject);
  });
}

const server = http.createServer(async (request, response) => {
  if (request.method === 'OPTIONS') {
    response.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    });
    return response.end();
  }

  // Create new pairing session
  if (request.method === 'POST' && request.url === '/v1/pairings') {
    const pairingId = `local_${randomUUID()}`;
    pairings.set(pairingId, { value: null });
    return sendJson(response, 200, {
      pairingId,
      qrPayload: `bridgesheet://pair?token=${pairingId}`,
    });
  }

  // Excel Add-in polling endpoint
  const inboxMatch = request.url.match(/^\/v1\/pairings\/([^/]+)\/inbox$/);
  if (request.method === 'GET' && inboxMatch) {
    const pairing = pairings.get(inboxMatch[1]);
    if (!pairing) return sendJson(response, 404, { error: 'Pairing not found' });
    if (!pairing.value) {
      response.writeHead(204, { 'Access-Control-Allow-Origin': '*' });
      return response.end();
    }
    const value = pairing.value;
    pairing.value = null;
    return sendJson(response, 200, { value, receivedAt: new Date().toISOString() });
  }

  // Submit new barcode / scanned value (from test or Flutter app)
  if (request.method === 'POST' && (request.url === '/v1/test-value' || request.url === '/v1/values')) {
    const data = await body(request);
    const pId = data.pairingId || data.token;
    
    // Find pairing by exact match or first active pairing if single test
    let pairing = pairings.get(pId);
    if (!pairing && pairings.size === 1 && !pId) {
      pairing = pairings.values().next().value;
    }
    
    if (!pairing) return sendJson(response, 404, { error: `Pairing not found for ID: ${pId}` });
    pairing.value = String(data.value ?? '');
    return sendJson(response, 202, { accepted: true, value: pairing.value });
  }

  // Serve static files (taskpane.html, taskpane.js, qrcode.min.js, icons, etc.)
  const requestedPath = new URL(request.url, 'http://localhost').pathname;
  const filePath = path.join(root, requestedPath === '/' ? 'taskpane.html' : requestedPath);
  if (!filePath.startsWith(root) || !fs.existsSync(filePath)) {
    response.writeHead(404);
    return response.end('Not found');
  }
  response.writeHead(200, {
    'Content-Type': mimeTypes[path.extname(filePath)] || 'application/octet-stream',
    'Access-Control-Allow-Origin': '*',
  });
  fs.createReadStream(filePath).pipe(response);
});

server.listen(port, '0.0.0.0', () => {
  console.log(`BridgeSheet local server running at http://localhost:${port}`);
  console.log(`Accessible on local network at http://0.0.0.0:${port}`);
  console.log(`Mock API ready at http://localhost:${port}/v1`);
});
