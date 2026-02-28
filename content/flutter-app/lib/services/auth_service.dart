import '../repositories/app_data_repository.dart';

class AuthService {
  AuthService({AppDataRepository? repository})
      : _repository = repository ?? AppDataRepository.instance;

  final AppDataRepository _repository;

  AuthStateSnapshot loadAuthState() {
    return _repository.loadAuthState();
  }

  bool validateCode(String code) {
    return code == '123456';
  }

  Future<void> saveLogin({
    required String phone,
    required String token,
  }) async {
    await _repository.saveAuthState(phone: phone, token: token);
  }

  Future<void> updatePhone(String phone) async {
    await _repository.savePhone(phone);
  }

  Future<void> clearLoginState() async {
    await _repository.clearAuthState();
    await _repository.clearChatState();
  }
}
