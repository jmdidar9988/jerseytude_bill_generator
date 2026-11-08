import 'package:flutter_test/flutter_test.dart';
import 'package:jerseytude_bill_generator/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JerseytudeBillGeneratorApp());
    expect(find.text('JERSEYTUDE'), findsOneWidget);
  });
}
