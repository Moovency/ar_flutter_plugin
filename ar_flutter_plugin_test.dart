import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';

void main() {
  const MethodChannel channel = MethodChannel('ar_flutter_plugin');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          String methodName = methodCall.method;

          switch (methodName) {
            case 'getPlatformVersion':
              return '42';

            case 'isArEnabled':
              return false;
            default:
              return '';
          }
        },
      );
    },
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await ArFlutterPlugin.platformVersion, '42');
  });

  test('isArEnabled', () async {
    expect(await ArFlutterPlugin.isArEnabled, false);
  });
}
