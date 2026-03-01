import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inaturalist_quiz/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: INaturalistQuizApp(),
      ),
    );

    expect(find.text('iNaturalist Quiz'), findsOneWidget);
    expect(find.text('Start Quiz'), findsOneWidget);
  });
}
