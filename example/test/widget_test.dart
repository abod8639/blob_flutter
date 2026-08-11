import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('ParticleBlobExampleApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ParticleBlobExampleApp());
    expect(find.byType(DashboardPage), findsOneWidget);
  });
}
