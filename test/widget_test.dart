import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('exibe o fluxo principal de envio', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Envie dados para o Excel'), findsOneWidget);
    expect(find.text('Estoque!B14'), findsOneWidget);
    expect(find.text('Enviar para Estoque!B14'), findsOneWidget);
  });
}
