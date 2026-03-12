import 'package:flutter/material.dart';
import '../config/app_env.dart';
import '../models/models.dart';
import '../services/match_service.dart';

class MatchProvider extends ChangeNotifier {
  final MatchService _matchService;
  int _matchCount = 20;
  bool _isMatching = false;
  User? _matchedUser;

  int get matchCount => _matchCount;
  bool get isMatching => _isMatching;
  User? get matchedUser => _matchedUser;

  static const List<Map<String, String>> _mockProfiles = [
    {
      'id': 'u_001',
      'uid': 'SNF0A101',
      'nickname': '阿澈',
      'avatar': '😄',
      'status': '想找人聊聊'
    },
    {
      'id': 'u_002',
      'uid': 'SNF0A102',
      'nickname': '小野',
      'avatar': '🙂',
      'status': '今晚有点失眠'
    },
    {
      'id': 'u_003',
      'uid': 'SNF0A103',
      'nickname': '晚风',
      'avatar': '🫧',
      'status': '随便聊聊'
    },
    {
      'id': 'u_004',
      'uid': 'SNF0A104',
      'nickname': 'Mia',
      'avatar': '🌙',
      'status': '分享今天的小事'
    },
    {
      'id': 'u_005',
      'uid': 'SNF0A105',
      'nickname': '阿宁',
      'avatar': '✨',
      'status': '想听听你的故事'
    },
    {
      'id': 'u_006',
      'uid': 'SNF0A106',
      'nickname': 'Echo',
      'avatar': '🎧',
      'status': '深夜在线'
    },
    {
      'id': 'u_007',
      'uid': 'SNF0A107',
      'nickname': '小北',
      'avatar': '🧩',
      'status': '想认识新朋友'
    },
    {
      'id': 'u_008',
      'uid': 'SNF0A108',
      'nickname': 'Kiki',
      'avatar': '🐱',
      'status': '今天心情不错'
    },
  ];

  MatchProvider({MatchService? matchService})
      : _matchService = matchService ?? MatchService() {
    _loadMatchCount();
    _checkDailyReset();
    _refreshRemoteQuota();
  }

  void _loadMatchCount() {
    _matchCount = _matchService.loadState().matchCount;
    notifyListeners();
  }

  Future<void> _checkDailyReset() async {
    final state = _matchService.loadState();
    final lastReset = state.lastResetDate;
    final now = DateTime.now();
    _matchCount = await _matchService.ensureDailyReset(
      now: now,
      currentCount: _matchCount,
      lastReset: lastReset,
    );
    notifyListeners();
  }

  Future<void> _refreshRemoteQuota() async {
    final state = await _matchService.refreshQuota();
    _matchCount = state.matchCount;
    notifyListeners();
  }

  Future<void> refreshFromRemote() async {
    await _refreshRemoteQuota();
  }

  Future<void> startMatch({Set<String>? excludedUserIds}) async {
    if (_matchCount <= 0 || _isMatching) return;

    _isMatching = true;
    _matchedUser = null;
    notifyListeners();

    final remoteResult = await _matchService.startMatch(
      excludedUserIds: (excludedUserIds ?? const <String>{}).toList(),
    );

    if (!_isMatching) return;

    if (remoteResult != null) {
      _matchedUser = remoteResult.user;
      _matchCount = remoteResult.remaining;
      _isMatching = false;
      notifyListeners();
      return;
    }

    if (!AppEnv.allowMockMatchPool) {
      _isMatching = false;
      _matchedUser = null;
      notifyListeners();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 2500));
    if (!_isMatching) return;
    _matchedUser = _generateMockUser(excludedUserIds: excludedUserIds);
    _isMatching = false;

    // 匹配成功，立即消耗次数
    await _consumeMatch(notify: false);
    notifyListeners();
  }

  void cancelMatch() {
    if (_isMatching) {
      _matchService.cancelMatch();
      _isMatching = false;
      _matchedUser = null;
      notifyListeners();
    }
  }

  Future<void> _consumeMatch({bool notify = true}) async {
    if (_matchCount > 0) {
      _matchCount--;
      await _matchService.saveMatchCount(_matchCount);
      if (notify) {
        notifyListeners();
      }
    }
  }

  void clearMatchedUser() {
    _matchedUser = null;
    notifyListeners();
  }

  User _generateMockUser({Set<String>? excludedUserIds}) {
    final excluded = excludedUserIds ?? const <String>{};
    final availableProfiles = _mockProfiles
        .where((profile) => !excluded.contains(profile['id']))
        .toList();
    final profileList =
        availableProfiles.isNotEmpty ? availableProfiles : _mockProfiles;
    final profile =
        profileList[DateTime.now().millisecond % profileList.length];

    // 70%概率匹配到在线用户（优先在线）
    final isOnline = DateTime.now().millisecond % 10 < 7;

    // 在线用户80%有位置权限，离线用户0%有位置权限
    final hasLocationPermission = isOnline && (DateTime.now().second % 10 < 8);

    return User(
      id: profile['id']!,
      uid: profile['uid'],
      nickname: profile['nickname']!,
      avatar: profile['avatar'],
      // 离线用户不显示位置，显示"未知"
      distance: hasLocationPermission
          ? '${(1 + (DateTime.now().millisecond % 50))}km'
          : '位置未知',
      status: profile['status']!,
      isOnline: isOnline,
      hasLocationPermission: hasLocationPermission,
      lastOnlineTime: isOnline
          ? DateTime.now()
          : DateTime.now().subtract(
              Duration(minutes: 5 + (DateTime.now().second % 55)),
            ),
    );
  }
}
