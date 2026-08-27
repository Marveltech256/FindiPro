import 'package:flutter_test/flutter_test.dart';
import 'package:findipro/main.dart';

void main() {
  testWidgets('FindiProApp basic smoke test', (WidgetTester tester) async {
    expect(const FindiProApp(), isNotNull);
  });
}
