# BridgeSheet Excel Add-in

Suplemento do Excel que lê a célula selecionada e recebe valores do aplicativo móvel BridgeSheet.

## Estrutura

- `manifest.xml`: manifesto do Office Add-in para instalação e publicação.
- `taskpane.html`: painel aberto dentro do Excel.
- `taskpane.js`: integração com Excel JavaScript API e API BridgeSheet.
- `taskpane.css`: estilos do painel.

## Contrato esperado da API

### Criar pareamento

`POST /v1/pairings`

```json
{
  "cell": "Estoque!B14"
}
```

Resposta `200`:

```json
{
  "pairingId": "pair_abc123",
  "qrPayload": "bridgesheet://pair?token=..."
}
```

O `qrPayload` deve conter o token persistente do dispositivo. O suplemento salva o `pairingId` em `localStorage` e restaura a conexão automaticamente ao abrir outra planilha no mesmo ambiente do Excel.

Ao gerar um novo QR Code, o vínculo anterior é substituído. Se a sessão expirar ou for removida pelo servidor, será necessário parear novamente.

### Consultar caixa de entrada

`GET /v1/pairings/{pairingId}/inbox`

- `204`: nenhum valor novo.
- `200`:

```json
{
  "value": "7890123456789",
  "receivedAt": "2026-09-05T12:00:00Z"
}
```

Depois de retornar um item, a API deve confirmá-lo como consumido para evitar duplicidade.

## Desenvolvimento local

Hospede esta pasta em HTTPS e substitua `API_BASE` em `taskpane.js` pelo endereço da API. O Excel bloqueia conteúdo remoto inseguro em produção.

Para testar, carregue `manifest.xml` como suplemento personalizado no Excel para a Web ou no Excel desktop compatível.

### Teste local sem publicar

1. Instale o Node.js 18 ou superior.
2. No PowerShell, execute:

```powershell
cd "D:\proetos flutter\flutter_application_1\excel-addin"
node .\dev-server.js
```

3. No Excel para a Web, abra **Inserir > Suplementos > Mais Suplementos > Meus Suplementos > Carregar meu suplemento** e selecione `manifest.local.xml`.
4. No Excel desktop, use **Inserir > Meus Suplementos > Gerenciar Meus Suplementos > Carregar meu suplemento**. O suporte a sideload pode depender da política da organização.
5. Selecione uma célula, abra o BridgeSheet e clique em **Gerar QR Code de pareamento**. Neste teste, o valor exibido no painel é o identificador local.
6. Em outro PowerShell, envie um valor para a fila mock substituindo `local_ID` pelo identificador exibido:

```powershell
$body = @{ pairingId = "local_ID"; value = "7890123456789" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri http://localhost:3000/v1/test-value -ContentType 'application/json' -Body $body
```

Em até alguns segundos o valor deverá aparecer na célula selecionada. Esse teste valida o painel, a leitura da célula, a escrita via Excel JavaScript API e o fluxo de fila. Ele não valida câmera do celular, autenticação ou internet real.

Se o Excel bloquear `http://localhost`, use um certificado HTTPS local e altere as URLs em `manifest.local.xml` para `https://localhost:3000`.

## Publicação no Microsoft Marketplace

Antes do envio, substitua os domínios de exemplo no manifesto, hospede os arquivos em HTTPS estável, crie os ícones reais, valide o manifesto no Partner Center e prepare política de privacidade, termos de uso, suporte e descrição do produto. O Marketplace também exigirá que o serviço esteja funcional e que o fluxo de autenticação e tratamento de dados esteja documentado.
