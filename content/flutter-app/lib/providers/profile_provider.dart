import 'package:flutter/material.dart';
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

  void _loadProfile() {
    final profile = _profileService.loadProfile();
    _nickname = profile.nickname;
    _avatar = profile.avatar;
    _status = profile.status;
    _signature = profile.signature;
    _transparentHomepage = profile.transparentHomepage;
    _portraitFullscreenBackground = profile.portraitFullscreenBackground;
    notifyListeners();
  }

  Future<void> updateNickname(String nickname) async {
    _nickname = nickname;
    await _profileService.saveNickname(nickname);
    notifyListeners();
  }

  Future<void> updateAvatar(String avatar) async {
    _avatar = avatar;
    await _profileService.saveAvatar(avatar);
    notifyListeners();
  }

  Future<void> updateStatus(String status) async {
    _status = status;
    await _profileService.saveStatus(status);
    notifyListeners();
  }

  Future<void> updateSignature(String signature) async {
    final normalized = signature.trim().isEmpty
        ? ProfileService.defaultSignature
        : signature.trim();
    _signature = normalized;
    await _profileService.saveSignature(normalized);
    notifyListeners();
  }

  Future<void> updateTransparentHomepage(bool enabled) async {
    final normalized = _portraitFullscreenBackground ? enabled : false;
    _transparentHomepage = normalized;
    await _profileService.saveTransparentHomepage(normalized);
    notifyListeners();
  }

  Future<void> updatePortraitFullscreenBackground(bool enabled) async {
    _portraitFullscreenBackground = enabled;
    await _profileService.savePortraitFullscreenBackground(enabled);
    if (!enabled && _transparentHomepage) {
      _transparentHomepage = false;
      await _profileService.saveTransparentHomepage(false);
    }
    notifyListeners();
  }
}
