import 'package:flutter_test/flutter_test.dart';
import 'package:yt_autopub/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const TubeMagicApp());
    expect(find.text('TubeMagic'), findsOneWidget);
  });
}
