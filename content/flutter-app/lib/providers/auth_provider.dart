import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../utils/permission_manager.dart';

class AuthProvider extends ChangeNotifier {
  String? _phone;
  String? _token;
  bool _isLoggedIn = false;
  String _nickname = '神秘人';
  String _avatar = '👤';
  String _status = '想找人聊聊';
  
  bool get isLoggedIn => _isLoggedIn;
  String? get phone => _phone;
  String get nickname => _nickname;
  String get avatar => _avatar;
  String get status => _status;
  
  AuthProvider() {
    _loadAuth();
  }
  
  Future<void> _loadAuth() async {
    _phone = StorageService.getPhone();
    _token = StorageService.getToken();
    _isLoggedIn = _phone != null && _token != null;
    
    // 加载用户资料
    _nickname = StorageService.getNickname() ?? '神秘人';
    _avatar = StorageService.getAvatar() ?? '👤';
    _status = StorageService.getStatus() ?? '想找人聊聊';
    
    notifyListeners();
  }
  
  // 更新昵称
  Future<void> updateNickname(String nickname) async {
    _nickname = nickname;
    await StorageService.saveNickname(nickname);
    notifyListeners();
  }
  
  // 更新头像
  Future<void> updateAvatar(String avatar) async {
    _avatar = avatar;
    await StorageService.saveAvatar(avatar);
    notifyListeners();
  }
  
  // 更新状态
  Future<void> updateStatus(String status) async {
    _status = status;
    await StorageService.saveStatus(status);
    notifyListeners();
  }
  
  Future<bool> login(String phone, String code) async {
    // Mock验证
    if (code != '123456') {
      return false;
    }
    
    _phone = phone;
    _token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
    _isLoggedIn = true;
    
    await StorageService.savePhone(phone);
    await StorageService.saveToken(_token!);
    
    notifyListeners();
    return true;
  }
  
  Future<void> logout() async {
    _phone = null;
    _token = null;
    _isLoggedIn = false;
    
    await StorageService.clearAuth();
    
    // 清除位置权限缓存
    PermissionManager.clearSessionCache();
    
    notifyListeners();
  }
}


