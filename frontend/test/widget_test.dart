import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart';
import 'package:frontend/core/providers/auth_provider.dart';

void main() {
  testWidgets('App renders login screen initially', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MentalHealthApp(),
      ),
    );

    expect(find.textContaining('منصة الرعاية النفسية'), findsOneWidget);
  });
}
