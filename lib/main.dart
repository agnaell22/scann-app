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
      title: 'BridgeSheet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D6B5B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
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
    text: 'https://api.bridgesheet.app/v1/values',
  );
  String _selectedCell = 'Estoque!B14';
  String _lastSent = 'Nenhum dado enviado ainda';
  bool _isSending = false;

  @override
  void dispose() {
    _valueController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _scanCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _valueController.text = result);
    }
  }

  Future<void> _pairDevice() async {
    final paired = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parear com a planilha'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 96),
            SizedBox(height: 12),
            Text(
              'No suplemento BridgeSheet do Excel, abra Conectar aparelho e leia o QR Code exibido.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Ler QR Code'),
          ),
        ],
      ),
    );
    if (paired == true && mounted) {
      final token = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const ScannerPage()),
      );
      if (token != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aparelho pareado com sucesso.')),
        );
      }
    }
  }

  Future<void> _sendValue() async {
    final value = _valueController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite ou leia um valor antes de enviar.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final response = await http.post(
        Uri.parse(_endpointController.text.trim()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cell': _selectedCell,
          'value': value,
          'source': 'android',
        }),
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _lastSent = '$value -> $_selectedCell';
          _valueController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valor enviado para a planilha.')),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível conectar à API. Verifique o endpoint.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BridgeSheet'),
        actions: [
          IconButton(
            onPressed: _pairDevice,
            tooltip: 'Parear aparelho',
            icon: const Icon(Icons.qr_code_2_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Envie dados para o Excel',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'O suplemento define a célula. Você só informa o próximo valor.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _StatusCard(onPair: _pairDevice),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Destino atual', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCell,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.table_chart_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const ['Estoque!B14', 'Pedidos!C8', 'Conferência!A2']
                          .map((cell) => DropdownMenuItem(value: cell, child: Text(cell)))
                          .toList(),
                      onChanged: (value) => setState(
                        () => _selectedCell = value ?? _selectedCell,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Novo valor', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _valueController,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Digite ou leia um código',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        suffixIcon: IconButton(
                          onPressed: _scanCode,
                          tooltip: 'Ler código de barras',
                          icon: const Icon(Icons.qr_code_scanner),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSending ? null : _sendValue,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_isSending ? 'Enviando...' : 'Enviar para $_selectedCell'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.history_rounded),
              title: const Text('Último envio'),
              subtitle: Text(_lastSent),
            ),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Configuração da API'),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: TextField(
                    controller: _endpointController,
                    decoration: const InputDecoration(
                      labelText: 'Endpoint HTTPS',
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.onPair});

  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: CircleAvatar(
          backgroundColor: colors.primary,
          child: Icon(Icons.link_rounded, color: colors.onPrimary),
        ),
        title: const Text(
          'Nenhuma planilha conectada',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('Leia o QR Code do suplemento BridgeSheet'),
        trailing: IconButton(
          onPressed: onPair,
          tooltip: 'Conectar',
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
    );
  }
}

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ler código')),
      body: MobileScanner(
        onDetect: (capture) {
          final value = capture.barcodes.firstOrNull?.rawValue;
          if (value != null && value.isNotEmpty) Navigator.pop(context, value);
        },
      ),
    );
  }
}
