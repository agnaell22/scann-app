import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BridgeSheet Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D6B5B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      home: const BridgeSheetPage(),
    );
  }
}

class BridgeSheetPage extends StatefulWidget {
  const BridgeSheetPage({super.key});

  @override
  State<BridgeSheetPage> createState() => _BridgeSheetPageState();
}

class _BridgeSheetPageState extends State<BridgeSheetPage> {
  final _valueController = TextEditingController();
  final _endpointController = TextEditingController(
    text: 'https://scann-app-seven.vercel.app/v1/values',
  );
  
  String? _pairedToken;
  String _lastSent = 'Nenhum dado enviado ainda';
  bool _isSending = false;

  @override
  void dispose() {
    _valueController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  void _extractTokenFromQr(String rawCode) {
    String token = rawCode.trim();
    if (token.contains('token=')) {
      final uri = Uri.tryParse(token);
      if (uri != null && uri.queryParameters.containsKey('token')) {
        token = uri.queryParameters['token']!;
      } else {
        final match = RegExp(r'token=([^&]+)').firstMatch(token);
        if (match != null) token = match.group(1)!;
      }
    }
    setState(() => _pairedToken = token);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0D6B5B),
        content: Text('✓ Planilha pareada com sucesso! Token: $token'),
      ),
    );
  }

  Future<void> _pairDevice() async {
    try {
      final scannedCode = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const ScannerPage(title: 'Escanear QR Code do Excel'),
        ),
      );
      if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
        _extractTokenFromQr(scannedCode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Erro ao abrir leitor de QR Code: $e'),
          ),
        );
      }
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const ScannerPage(title: 'Escanear Código de Barras'),
        ),
      );
      if (barcode != null && barcode.isNotEmpty && mounted) {
        setState(() => _valueController.text = barcode);
        if (_pairedToken != null) {
          _sendValue();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Erro ao abrir leitor de câmera: $e'),
          ),
        );
      }
    }
  }

  Future<void> _sendValue() async {
    final value = _valueController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite ou escaneie um valor primeiro.')),
      );
      return;
    }

    if (_pairedToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leia o QR Code do suplemento Excel antes de enviar.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final response = await http.post(
        Uri.parse(_endpointController.text.trim()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pairingId': _pairedToken,
          'token': _pairedToken,
          'value': value,
          'source': 'android',
        }),
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _lastSent = '$value → Enviado para Excel';
          _valueController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0D6B5B),
            content: Text('✓ Valor enviado para o Excel com sucesso!'),
          ),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Erro ao enviar para o Excel. Verifique o IP/Endpoint.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaired = _pairedToken != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D6B5B),
        foregroundColor: Colors.white,
        title: const Text('BridgeSheet Mobile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _pairDevice,
            tooltip: 'Parear com Excel',
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status Card
            Card(
              elevation: 0,
              color: isPaired ? const Color(0xFFE6F4F1) : const Color(0xFFFEF3C7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isPaired ? const Color(0xFF0D6B5B).withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.3),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isPaired ? const Color(0xFF0D6B5B) : const Color(0xFFF59E0B),
                  child: Icon(
                    isPaired ? Icons.link_rounded : Icons.link_off_rounded,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  isPaired ? 'Excel Conectado' : 'Aparelho Não Pareado',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isPaired ? 'Token: $_pairedToken' : 'Toque no ícone de QR Code para ler o suplemento.',
                ),
                trailing: TextButton(
                  onPressed: _pairDevice,
                  child: Text(isPaired ? 'Re-parear' : 'Parear'),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Value Input Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VALOR A BIPAR / INSERIR',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _valueController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendValue(),
                      decoration: InputDecoration(
                        hintText: 'Digite ou escaneie o código...',
                        prefixIcon: const Icon(Icons.barcode_reader),
                        suffixIcon: IconButton(
                          onPressed: _scanBarcode,
                          tooltip: 'Abrir Leitor de Câmera',
                          icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0D6B5B)),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D6B5B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSending ? null : _sendValue,
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _isSending ? 'Enviando...' : 'Enviar para o Excel',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Last sent log
            ListTile(
              leading: const Icon(Icons.history_rounded, color: Color(0xFF0D6B5B)),
              title: const Text('Último Envio'),
              subtitle: Text(_lastSent, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Divider(),

            // Configuration Expansion
            ExpansionTile(
              title: const Text('Configuração da API / IP do PC'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _endpointController,
                    decoration: const InputDecoration(
                      labelText: 'Endpoint da API (ex: http://192.168.1.50:3000/v1/values)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.title});
  final String title;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  late final MobileScannerController controller;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF0D6B5B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                if (state.torchState == TorchState.on) {
                  return const Icon(Icons.flash_on, color: Colors.yellowAccent);
                }
                return const Icon(Icons.flash_off, color: Colors.white70);
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        errorBuilder: (context, error, child) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao inicializar câmera: ${error.errorCode}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.errorDetails?.message ??
                        'Certifique-se de que a permissão de câmera foi concedida no sistema.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => controller.start(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            ),
          );
        },
        onDetect: (capture) {
          final barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final val = barcode.rawValue;
            if (val != null && val.isNotEmpty) {
              Navigator.pop(context, val);
              break;
            }
          }
        },
      ),
    );
  }
}
