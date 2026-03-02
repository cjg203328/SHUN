import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunliao/repositories/app_data_repository.dart';
import 'package:sunliao/services/storage_service.dart';

Future<void> initTestAppStorage({
  Map<String, Object> initialValues = const <String, Object>{},
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(initialValues);
  await StorageService.init();
  await AppDataRepository.instance.bootstrap();
}
