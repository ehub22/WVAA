import 'package:flutter_test/flutter_test.dart';
import 'package:westview_app/data.dart';
import 'package:westview_app/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('schedule data loads without errors', () {
    expect(monFriSchedule, isNotEmpty);
    expect(tueThursSchedule, isNotEmpty);
    expect(wedSchedule, isNotEmpty);
  });

  test('settings singleton is accessible', () {
    expect(AppSettings.instance, isNotNull);
  });
}
