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
    _applyProfile(_profileService.loadProfile());
    notifyListeners();

    try {
      final profile = await _profileService.refreshProfile();
      _applyProfile(profile);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshFromRemote() async {
    final profile = await _profileService.refreshProfile();
    _applyProfile(profile);
    notifyListeners();
  }

  void _applyProfile(ProfileStateSnapshot profile) {
    _nickname = profile.nickname;
    _avatar = profile.avatar;
    _status = profile.status;
    _signature = profile.signature;
    _transparentHomepage = profile.transparentHomepage;
    _portraitFullscreenBackground = profile.portraitFullscreenBackground;
  }

  Future<void> updateNickname(String nickname) async {
    final profile = await _profileService.saveNickname(nickname);
    _applyProfile(profile);
    notifyListeners();
  }

  Future<void> updateAvatar(String avatar) async {
    _avatar = avatar;
    await _profileService.saveAvatar(avatar);
    notifyListeners();
  }

  Future<void> updateStatus(String status) async {
    final profile = await _profileService.saveStatus(status);
    _applyProfile(profile);
    notifyListeners();
  }

  Future<void> updateSignature(String signature) async {
    final profile = await _profileService.saveSignature(signature);
    _applyProfile(profile);
    notifyListeners();
  }

  Future<void> updateTransparentHomepage(bool enabled) async {
    final normalized = _portraitFullscreenBackground ? enabled : false;
    final profile = await _profileService.saveTransparentHomepage(normalized);
    _applyProfile(profile);
    notifyListeners();
  }

  Future<void> updatePortraitFullscreenBackground(bool enabled) async {
    final profile = await _profileService.savePortraitFullscreenBackground(enabled);
    _applyProfile(profile);
    notifyListeners();
  }
}
