import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('BlobExampleApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BlobExampleApp());
    expect(find.byType(BlobShowcasePage), findsOneWidget);
  });
}
