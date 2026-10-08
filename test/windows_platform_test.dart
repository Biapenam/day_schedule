import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:day_schedule/screens/settings_screen.dart';
import 'package:day_schedule/services/widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'settings only offer home widgets on Android',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final supported = defaultTargetPlatform == TargetPlatform.android;
      expect(WidgetService.supportsHomeWidgets, supported);
      if (!supported) {
        // Unsupported platforms must not invoke an Android plugin channel.
        await WidgetService.init();
        await WidgetService().updateWidget();
        expect(
          await WidgetService().requestPinWidget(),
          'unsupported_platform',
        );
      }
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('导出课表'), findsOneWidget);
      expect(find.text('从口令导入'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(supported ? '桌面小卡片' : '关于'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('添加桌面小卡片'), supported ? findsOneWidget : findsNothing);
      expect(find.text('如何手动添加'), supported ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );
}
