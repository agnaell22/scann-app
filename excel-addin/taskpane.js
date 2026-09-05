/* BridgeSheet Excel Add-in Logic */
const API_BASE = new URLSearchParams(window.location.search).get('api')
  || 'http://localhost:3000/v1';
const POLL_INTERVAL_MS = 2000;

let pairingId = null;
let pollTimer = null;
let activeAddress = null;
let qrCodeObj = null;

Office.onReady(async (info) => {
  if (info.host !== Office.HostType.Excel) {
    showMessage('Abra este suplemento dentro do Microsoft Excel.', 'error');
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
    showMessage('Não foi possível sincronizar a célula ativa.', 'error');
  }
}

async function createPairing() {
  const button = document.getElementById('pair-button');
  button.disabled = true;
  button.innerHTML = `
    <svg class="spin" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>
    </svg>
    Gerando QR Code...
  `;

  try {
    const response = await fetch(`${API_BASE}/pairings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ cell: activeAddress }),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const data = await response.json();
    pairingId = data.pairingId;

    // Render QR Code Image
    const qrContainer = document.getElementById('qrcode');
    qrContainer.innerHTML = '';
    qrCodeObj = new QRCode(qrContainer, {
      text: data.qrPayload,
      width: 180,
      height: 180,
      colorDark: "#0D6B5B",
      colorLight: "#FFFFFF",
      correctLevel: QRCode.CorrectLevel.H
    });

    document.getElementById('pairing-code').textContent = data.pairingId;
    document.getElementById('qr-wrapper').classList.remove('hidden');
    document.getElementById('connection-status').textContent = 'Pronto para Parear';
    document.getElementById('status-dot').className = 'status-dot warning';
    
    showMessage('Escaneie o QR Code no app BridgeSheet para iniciar.', 'info');

    if (pollTimer) clearInterval(pollTimer);
    pollTimer = setInterval(pollForValue, POLL_INTERVAL_MS);
  } catch (error) {
    showMessage('Erro ao conectar à API local. Verifique se o servidor está rodando.', 'error');
  } finally {
    button.disabled = false;
    button.innerHTML = `
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/>
      </svg>
      Gerar Novo QR Code
    `;
  }
}

async function pollForValue() {
  if (!pairingId) return;

  try {
    const response = await fetch(`${API_BASE}/pairings/${encodeURIComponent(pairingId)}/inbox`);
    if (response.status === 204) return;
    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const item = await response.json();

    // 1. Write value and auto-advance selection to cell below
    await writeToActiveCellAndAdvance(item.value);

    // 2. Update UI status
    const lastValElem = document.getElementById('last-value');
    const lastTimeElem = document.getElementById('last-time');
    const lastBoxElem = document.getElementById('last-value-box');

    lastValElem.textContent = item.value;
    lastTimeElem.textContent = `Registrado às ${new Date().toLocaleTimeString('pt-BR')}`;
    
    // Trigger visual pulse animation
    lastBoxElem.classList.remove('pulse-success');
    void lastBoxElem.offsetWidth; // Force reflow
    lastBoxElem.classList.add('pulse-success');

    document.getElementById('connection-status').textContent = 'Conectado';
    document.getElementById('status-dot').className = 'status-dot online';
    document.getElementById('connection-pill').classList.add('connected');
    
    showMessage(`Valor "${item.value}" inserido com sucesso! Seleção avançada.`, 'success');
  } catch (error) {
    showMessage('Conexão com a API foi interrompida.', 'error');
  }
}

/**
 * Writes the received value to the current active cell and moves the selection
 * to the cell immediately below (row + 1, col + 0) for seamless sequential scanning.
 */
async function writeToActiveCellAndAdvance(value) {
  await Excel.run(async (context) => {
    const range = context.workbook.getSelectedRange();
    range.values = [[value]];
    range.format.autofitColumns();

    // Move selection cursor to the row directly below
    const nextCell = range.getOffsetRange(1, 0);
    nextCell.select();

    await context.sync();
  });
  await refreshActiveCell();
}

function showMessage(text, type = 'info') {
  const msgElem = document.getElementById('message');
  msgElem.textContent = text;
  msgElem.className = `message-banner ${type}`;
}
