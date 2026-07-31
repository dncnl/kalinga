import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/pages/role_select_page.dart';
import 'package:mobile/theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Accessibility Guidelines Tests', () {
    testWidgets('RoleSelectPage passes accessibility guidelines',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: const RoleSelectPage(),
        ),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      handle.dispose();
    });

    testWidgets('RoleSelectPage handles font scaling at 2.0x without breaking',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            );
          },
          home: const RoleSelectPage(),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
