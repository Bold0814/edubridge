import 'package:flutter_test/flutter_test.dart';

import 'package:edubridge/main.dart';
import 'package:edubridge/state/app_store.dart';

void main() {
  testWidgets('EduBridge эхний дэлгэц харагдана', (WidgetTester tester) async {
    await tester.pumpWidget(EduBridgeApp(store: AppStore()));
    await tester.pumpAndSettle();

    expect(find.text('Анги сонгох'), findsWidgets);

    await tester.tap(find.text('6А анги'));
    await tester.pumpAndSettle();

    expect(find.text('Нүүр'), findsWidgets);
    expect(find.text('6А анги'), findsWidgets);
    expect(find.text('Сурагчид'), findsOneWidget);
    expect(find.text('Хичээлийн журнал'), findsOneWidget);
    expect(find.text('Сүүлийн үйл ажиллагаа'), findsOneWidget);
  });
}
