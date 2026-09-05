/* Replace API_BASE with the production HTTPS origin before publishing. */
const API_BASE = new URLSearchParams(window.location.search).get('api')
  || 'https://api.bridgesheet.app/v1';
const POLL_INTERVAL_MS = 2500;

let pairingId = null;
let pollTimer = null;
let activeAddress = null;

Office.onReady(async (info) => {
  if (info.host !== Office.HostType.Excel) {
    showMessage('Abra este suplemento dentro do Excel.');
    return;
  }

  await refreshActiveCell();
  document.getElementById('pair-button').addEventListener('click', createPairing);
  setInterval(refreshActiveCell, 1500);
});

async function refreshActiveCell() {
  try {
    await Excel.run(async (context) => {
      const range = context.workbook.getSelectedRange();
      range.load(['address', 'worksheet/name']);
      await context.sync();
      activeAddress = `${range.worksheet.name}!${range.address.split('!').pop()}`;
      document.getElementById('active-cell').textContent = activeAddress;
    });
  } catch (error) {
    showMessage('Não foi possível ler a célula ativa.');
  }
}

async function createPairing() {
  const button = document.getElementById('pair-button');
  button.disabled = true;
  button.textContent = 'Criando conexão...';

  try {
    const response = await fetch(`${API_BASE}/pairings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ cell: activeAddress }),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const data = await response.json();
    pairingId = data.pairingId;
    document.getElementById('pairing-code').textContent = data.qrPayload;
    document.getElementById('pairing-code').classList.remove('hidden');
    document.getElementById('connection-status').textContent = 'QR Code pronto para leitura';
    showMessage('Leia o código no aplicativo BridgeSheet.');
    pollTimer = setInterval(pollForValue, POLL_INTERVAL_MS);
  } catch (error) {
    showMessage('Não foi possível criar o pareamento. Verifique a API.');
  } finally {
    button.disabled = false;
    button.textContent = 'Gerar QR Code de pareamento';
  }
}

async function pollForValue() {
  if (!pairingId) return;

  try {
    const response = await fetch(`${API_BASE}/pairings/${encodeURIComponent(pairingId)}/inbox`);
    if (response.status === 204) return;
    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const item = await response.json();
    await writeToActiveCell(item.value);
    document.getElementById('last-value').textContent = item.value;
    document.getElementById('last-time').textContent = `Recebido às ${new Date().toLocaleTimeString('pt-BR')}`;
    document.getElementById('connection-status').textContent = 'Aparelho conectado';
    document.getElementById('status-dot').className = 'dot online';
    showMessage('Valor escrito na célula selecionada.');
  } catch (error) {
    showMessage('A conexão com a API foi interrompida.');
  }
}

async function writeToActiveCell(value) {
  await Excel.run(async (context) => {
    const range = context.workbook.getSelectedRange();
    range.values = [[value]];
    range.format.autofitColumns();
    await context.sync();
  });
}

function showMessage(message) {
  document.getElementById('message').textContent = message;
}
