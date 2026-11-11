// Retain compatibility with Flutter versions before the Material package split.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhamar_complaints/main.dart';
import 'package:dhamar_complaints/store.dart';

void main() {
  testWidgets('Arabic login leads to citizen dashboard', (tester) async {
    await tester.pumpWidget(ComplaintsApp(store: DemoStore()));
    expect(find.text('صوتك يصل'), findsOneWidget);
    await tester.ensureVisible(find.text('تعبئة حساب المواطن'));
    await tester.tap(find.text('تعبئة حساب المواطن'));
    await tester.pump();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'تسجيل الدخول'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('شكواي'), findsOneWidget);
    expect(find.text('تقديم شكوى'), findsOneWidget);
  });
  testWidgets('mobile citizen can open complaint and new complaint form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = DemoStore();
    await store.login('citizen@example.com', 'Demo12345!');
    await tester.pumpWidget(ComplaintsApp(store: store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('انقطاع المياه عن الحي'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('انقطاع المياه عن الحي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('انقطاع المياه عن الحي'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الشكوى'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تقديم شكوى'));
    await tester.pumpAndSettle();
    expect(find.text('تقديم شكوى جديدة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
