import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('bundled Baloo2 static weights are present as assets', () async {
    const files = [
      'assets/google_fonts/Baloo2-Regular.ttf',
      'assets/google_fonts/Baloo2-Medium.ttf',
      'assets/google_fonts/Baloo2-SemiBold.ttf',
      'assets/google_fonts/Baloo2-Bold.ttf',
      'assets/google_fonts/Baloo2-ExtraBold.ttf',
      'assets/google_fonts/OFL.txt',
    ];
    for (final path in files) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(100), reason: path);
    }
  });

  testWidgets('GoogleFonts.baloo2 resolves offline without network',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Text(
            'Runners Rush',
            style: GoogleFonts.baloo2(
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Runners Rush'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Runners Rush'));
    expect(text.style?.fontFamily, contains('Baloo2'));
  });
}
