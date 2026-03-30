import 'package:flutter/material.dart';
import '../repositories/app_data_repository.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({ProfileService? profileService})
      : _profileService = profileService ?? ProfileService() {
    _loadProfile();
  }

  final ProfileService _profileService;

  String _nickname = '神秘人';
  String _avatar = '👤';
  String _status = '想找人聊聊';
  String _signature = ProfileService.defaultSignature;
  bool _transparentHomepage = false;
  bool _portraitFullscreenBackground = false;

  String get nickname => _nickname;
  String get avatar => _avatar;
  String get status => _status;
  String get signature => _signature;
  bool get transparentHomepage => _transparentHomepage;
  bool get portraitFullscreenBackground => _portraitFullscreenBackground;

  Future<void> _loadProfile() async {
    _notifyIfChanged(_applyProfile(_profileService.loadProfile()));

    try {
      final profile = await _profileService.refreshProfile();
      _notifyIfChanged(_applyProfile(profile));
    } catch (_) {}
  }

  Future<void> refreshFromRemote() async {
    await refreshFromRemoteWithStatus();
  }

  Future<ProfileRefreshResult> refreshFromRemoteWithStatus() async {
    final result = await _profileService.refreshProfileWithStatus();
    _notifyIfChanged(_applyProfile(result.snapshot));
    return result;
  }

  bool _applyProfile(ProfileStateSnapshot profile) {
    final didChange = _nickname != profile.nickname ||
        _avatar != profile.avatar ||
        _status != profile.status ||
        _signature != profile.signature ||
        _transparentHomepage != profile.transparentHomepage ||
        _portraitFullscreenBackground != profile.portraitFullscreenBackground;

    if (!didChange) {
      return false;
    }

    _nickname = profile.nickname;
    _avatar = profile.avatar;
    _status = profile.status;
    _signature = profile.signature;
    _transparentHomepage = profile.transparentHomepage;
    _portraitFullscreenBackground = profile.portraitFullscreenBackground;
    return true;
  }

  void _notifyIfChanged(bool didChange) {
    if (didChange) {
      notifyListeners();
    }
  }

  Future<void> updateNickname(String nickname) async {
    final profile = await _profileService.saveNickname(nickname);
    _notifyIfChanged(_applyProfile(profile));
  }

  Future<ProfileSaveResult> updateNicknameWithStatus(String nickname) async {
    final result = await _profileService.saveNicknameWithStatus(nickname);
    _notifyIfChanged(_applyProfile(result.snapshot));
    return result;
  }

  Future<void> updateAvatar(String avatar) async {
    if (_avatar == avatar) {
      return;
    }

    _avatar = avatar;
    notifyListeners();
    await _profileService.saveAvatar(avatar);
  }

  Future<void> updateStatus(String status) async {
    final profile = await _profileService.saveStatus(status);
    _notifyIfChanged(_applyProfile(profile));
  }

  Future<ProfileSaveResult> updateStatusWithStatus(String status) async {
    final result = await _profileService.saveStatusWithStatus(status);
    _notifyIfChanged(_applyProfile(result.snapshot));
    return result;
  }

  Future<void> updateSignature(String signature) async {
    final profile = await _profileService.saveSignature(signature);
    _notifyIfChanged(_applyProfile(profile));
  }

  Future<ProfileSaveResult> updateSignatureWithStatus(String signature) async {
    final result = await _profileService.saveSignatureWithStatus(signature);
    _notifyIfChanged(_applyProfile(result.snapshot));
    return result;
  }

  Future<void> updateTransparentHomepage(bool enabled) async {
    final normalized = _portraitFullscreenBackground ? enabled : false;
    final profile = await _profileService.saveTransparentHomepage(normalized);
    _notifyIfChanged(_applyProfile(profile));
  }

  Future<void> updatePortraitFullscreenBackground(bool enabled) async {
    final profile =
        await _profileService.savePortraitFullscreenBackground(enabled);
    _notifyIfChanged(_applyProfile(profile));
  }
}
