import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runners_rush/screens/home_screen.dart';
import 'package:runners_rush/services/settings_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.resetForTests();
  });

  const sizes = <Size>[
    Size(640, 360),
    Size(800, 360),
    Size(892, 412),
    Size(568, 320),
  ];

  for (final size in sizes) {
    for (final female in [false, true]) {
      final label = female ? 'female' : 'male';
      testWidgets(
        'home $label preview fits inside ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          SharedPreferences.setMockInitialValues(
            female
                ? {
                    'selected_character': 'female',
                    'unlocked_characters': ['male', 'female'],
                  }
                : {},
          );

          await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          final preview = find.byKey(const ValueKey('home-character-preview'));
          expect(preview, findsOneWidget);

          final rect = tester.getRect(preview);
          final context = tester.element(preview);
          final padding = MediaQuery.paddingOf(context);

          const eps = 1.0;
          expect(
            rect.top,
            greaterThanOrEqualTo(padding.top - eps),
            reason: 'preview top must be below SafeArea top',
          );
          expect(rect.left, greaterThanOrEqualTo(-eps));
          expect(rect.right, lessThanOrEqualTo(size.width + eps));
          expect(rect.bottom, lessThanOrEqualTo(size.height + eps));
          expect(rect.height, greaterThan(0));
          expect(rect.width, greaterThan(0));
        },
      );
    }
  }
}
