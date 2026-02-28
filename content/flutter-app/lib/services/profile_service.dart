import '../repositories/app_data_repository.dart';

class ProfileService {
  ProfileService({AppDataRepository? repository})
      : _repository = repository ?? AppDataRepository.instance;

  final AppDataRepository _repository;

  static const String defaultSignature = '这个人很神秘，什么都没留下';

  ProfileStateSnapshot loadProfile() {
    return _repository.loadProfileState();
  }

  Future<void> saveNickname(String nickname) async {
    await _repository.saveNickname(nickname);
  }

  Future<void> saveAvatar(String avatar) async {
    await _repository.saveAvatar(avatar);
  }

  Future<void> saveStatus(String status) async {
    await _repository.saveStatus(status);
  }

  Future<void> saveSignature(String signature) async {
    await _repository.saveSignature(
      signature.trim().isEmpty ? defaultSignature : signature.trim(),
    );
  }

  Future<void> saveTransparentHomepage(bool enabled) async {
    await _repository.saveTransparentHomepage(enabled);
  }

  Future<void> savePortraitFullscreenBackground(bool enabled) async {
    await _repository.savePortraitFullscreenBackground(enabled);
  }
}
