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
    });
    return response.end();
  }

  if (request.method === 'POST' && request.url === '/v1/pairings') {
    const pairingId = `local_${randomUUID()}`;
    pairings.set(pairingId, { value: null });
    return sendJson(response, 200, {
      pairingId,
      qrPayload: `bridgesheet://pair?token=${pairingId}`,
    });
  }

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

  if (request.method === 'POST' && request.url === '/v1/test-value') {
    const data = await body(request);
    const pairing = pairings.get(data.pairingId);
    if (!pairing) return sendJson(response, 404, { error: 'Pairing not found' });
    pairing.value = String(data.value ?? '');
    return sendJson(response, 202, { accepted: true });
  }

  const requestedPath = new URL(request.url, 'http://localhost').pathname;
  const filePath = path.join(root, requestedPath === '/' ? 'taskpane.html' : requestedPath);
  if (!filePath.startsWith(root) || !fs.existsSync(filePath)) {
    response.writeHead(404);
    return response.end('Not found');
  }
  response.writeHead(200, { 'Content-Type': mimeTypes[path.extname(filePath)] || 'application/octet-stream' });
  fs.createReadStream(filePath).pipe(response);
});

server.listen(port, 'localhost', () => {
  console.log(`BridgeSheet local server: http://localhost:${port}`);
  console.log('Mock API ready at http://localhost:3000/v1');
});
