import 'package:flutter_test/flutter_test.dart';
import 'package:greenlight_app/main.dart';

void main() {
  testWidgets('Открывается стартовый экран GreenLight', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GreenLightApp());

    expect(find.text('GreenLight'), findsOneWidget);
    expect(find.text('Войти в аккаунт'), findsOneWidget);
    expect(find.text('Создать аккаунт'), findsOneWidget);
    expect(find.text('Продолжить без аккаунта'), findsOneWidget);
  });
}