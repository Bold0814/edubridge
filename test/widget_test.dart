import 'package:flutter_test/flutter_test.dart';

import 'package:edubridge/main.dart';

void main() {
  testWidgets('EduBridge эхний дэлгэц харагдана', (WidgetTester tester) async {
    await tester.pumpWidget(const EduBridgeApp());
    await tester.pumpAndSettle();

    expect(find.text('Зарлал'), findsWidgets);
  });
}
