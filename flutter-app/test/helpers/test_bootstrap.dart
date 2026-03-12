import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunliao/repositories/app_data_repository.dart';
import 'package:sunliao/services/storage_service.dart';

const MethodChannel _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

Future<void> initTestAppStorage({
  Map<String, Object> initialValues = const <String, Object>{},
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_permissionChannel, (call) async {
    switch (call.method) {
      case 'checkPermissionStatus':
        return 1;
      case 'requestPermissions':
        final arguments = call.arguments;
        if (arguments is List) {
          return <int, int>{
            for (final permission in arguments.whereType<int>()) permission: 1,
          };
        }
        return <int, int>{};
      case 'shouldShowRequestPermissionRationale':
        return false;
      case 'checkServiceStatus':
        return 1;
      case 'openAppSettings':
        return true;
      default:
        return null;
    }
  });
  SharedPreferences.setMockInitialValues(initialValues);
  await StorageService.init();
  await AppDataRepository.instance.bootstrap();
}
