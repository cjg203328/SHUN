import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class MatchProvider extends ChangeNotifier {
  int _matchCount = 20;
  bool _isMatching = false;
  User? _matchedUser;
  
  int get matchCount => _matchCount;
  bool get isMatching => _isMatching;
  User? get matchedUser => _matchedUser;
  
  MatchProvider() {
    _loadMatchCount();
    _checkDailyReset();
  }
  
  void _loadMatchCount() {
    _matchCount = StorageService.getMatchCount();
    notifyListeners();
  }
  
  Future<void> _checkDailyReset() async {
    final lastReset = StorageService.getLastResetDate();
    final now = DateTime.now();
    
    if (lastReset == null || 
        (now.day != lastReset.day && now.hour >= 9)) {
      // 每天9点重置
      _matchCount = 20;
      await StorageService.saveMatchCount(20);
      await StorageService.saveLastResetDate(now);
      notifyListeners();
    }
  }
  
  Future<void> startMatch() async {
    if (_matchCount <= 0 || _isMatching) return;
    
    _isMatching = true;
    _matchedUser = null;
    notifyListeners();
    
    // 模拟匹配延迟
    await Future.delayed(const Duration(milliseconds: 2500));
    
    // 检查是否被取消
    if (!_isMatching) return;
    
    // Mock用户数据
    _matchedUser = _generateMockUser();
    _isMatching = false;
    
    // 匹配成功，立即消耗次数
    consumeMatch();
    notifyListeners();
  }
  
  void cancelMatch() {
    if (_isMatching) {
      _isMatching = false;
      _matchedUser = null;
      notifyListeners();
    }
  }
  
  void consumeMatch() {
    if (_matchCount > 0) {
      _matchCount--;
      StorageService.saveMatchCount(_matchCount);
      notifyListeners();
    }
  }
  
  void clearMatchedUser() {
    _matchedUser = null;
    notifyListeners();
  }
  
  User _generateMockUser() {
    final statuses = [
      '想找人聊聊',
      '有点失眠',
      '心情不好',
      '分享快乐',
      '深夜emo',
      '随便聊聊'
    ];
    
    // 70%概率匹配到在线用户（优先在线）
    final isOnline = DateTime.now().millisecond % 10 < 7;
    
    // 在线用户80%有位置权限，离线用户0%有位置权限
    final hasLocationPermission = isOnline && (DateTime.now().second % 10 < 8);
    
    return User(
      id: const Uuid().v4(),
      nickname: '神秘人',
      // 离线用户不显示位置，显示"未知"
      distance: hasLocationPermission 
          ? '${(1 + (DateTime.now().millisecond % 50))}km'
          : '位置未知',
      status: statuses[DateTime.now().second % statuses.length],
      isOnline: isOnline,
      hasLocationPermission: hasLocationPermission,
      lastOnlineTime: isOnline ? DateTime.now() : DateTime.now().subtract(
        Duration(minutes: 5 + (DateTime.now().second % 55)),
      ),
    );
  }
}

