import '../repositories/app_data_repository.dart';
import '../core/network/api_exception.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'storage_service.dart';

class MatchResult {
  final String matchId;
  final String threadId;
  final User user;
  final int remaining;
  final DateTime createdAt;
  final DateTime expiresAt;

  const MatchResult({
    required this.matchId,
    required this.threadId,
    required this.user,
    required this.remaining,
    required this.createdAt,
    required this.expiresAt,
  });
}

class MatchStartAttempt {
  const MatchStartAttempt._({
    this.result,
    this.errorCode,
    this.errorMessage,
  });

  const MatchStartAttempt.success(MatchResult result) : this._(result: result);

  const MatchStartAttempt.failure({
    required String errorCode,
    required String errorMessage,
  }) : this._(
          errorCode: errorCode,
          errorMessage: errorMessage,
        );

  final MatchResult? result;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => result != null;
}

class MatchService {
  MatchService({AppDataRepository? repository, ApiClient? apiClient})
      : _repository = repository ?? AppDataRepository.instance,
        _apiClient = apiClient ?? ApiClient.instance;

  final AppDataRepository _repository;
  final ApiClient _apiClient;

  static const int dailyQuota = 20;

  MatchStateSnapshot loadState() {
    return _repository.loadMatchState();
  }

  Future<MatchStateSnapshot> refreshQuota() async {
    if (!_hasSession) return loadState();

    try {
      final data = await _apiClient.get<Map<String, dynamic>>('/match/quota');
      final remaining = (data['remaining'] as num?)?.toInt() ?? dailyQuota;
      final lastResetDate = DateTime.tryParse(
        data['lastResetDate']?.toString() ?? '',
      );
      await _repository.saveMatchCount(remaining);
      if (lastResetDate != null) {
        await _repository.saveLastResetDate(lastResetDate);
      }
    } catch (_) {}

    return loadState();
  }

  Future<int> ensureDailyReset({
    required DateTime now,
    required int currentCount,
    required DateTime? lastReset,
  }) async {
    final hasSameDate = lastReset != null &&
        now.year == lastReset.year &&
        now.month == lastReset.month &&
        now.day == lastReset.day;
    final shouldReset = lastReset == null || (!hasSameDate && now.hour >= 9);
    if (!shouldReset) return currentCount;

    await _repository.saveMatchCount(dailyQuota);
    await _repository.saveLastResetDate(now);
    return dailyQuota;
  }

  Future<void> saveMatchCount(int count) async {
    await _repository.saveMatchCount(count);
  }

  Future<MatchStartAttempt> startMatch({
    required List<String> excludedUserIds,
  }) async {
    if (!_hasSession) {
      return const MatchStartAttempt.failure(
        errorCode: 'MATCH_SESSION_MISSING',
        errorMessage: '登录状态已失效，请重新进入后再试',
      );
    }

    try {
      final data = await _apiClient.post<Map<String, dynamic>>(
        '/match/start',
        data: {
          'excludeUserIds': excludedUserIds,
        },
      );

      final userJson = (data['user'] as Map?)?.cast<String, dynamic>();
      final quotaJson = (data['quota'] as Map?)?.cast<String, dynamic>();
      if (userJson == null) {
        return const MatchStartAttempt.failure(
          errorCode: 'MATCH_RESPONSE_INVALID',
          errorMessage: '匹配服务返回了不完整的数据，请稍后再试',
        );
      }

      final remaining =
          (quotaJson?['remaining'] as num?)?.toInt() ?? dailyQuota;
      await _repository.saveMatchCount(remaining);

      final resetDate = DateTime.tryParse(
        quotaJson?['lastResetDate']?.toString() ?? '',
      );
      if (resetDate != null) {
        await _repository.saveLastResetDate(resetDate);
      }

      return MatchStartAttempt.success(
        MatchResult(
          matchId: data['matchId']?.toString() ?? '',
          threadId: data['threadId']?.toString() ?? '',
          user: _mapUser(userJson),
          remaining: remaining,
          createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
              DateTime.now(),
          expiresAt: DateTime.tryParse(data['expiresAt']?.toString() ?? '') ??
              DateTime.now().add(const Duration(hours: 24)),
        ),
      );
    } on ApiException catch (error) {
      return MatchStartAttempt.failure(
        errorCode: error.code,
        errorMessage: error.userMessage,
      );
    } catch (_) {
      return const MatchStartAttempt.failure(
        errorCode: 'MATCH_START_FAILED',
        errorMessage: '匹配暂时不可用，请稍后重试',
      );
    }
  }

  Future<void> cancelMatch() async {
    if (!_hasSession) return;
    try {
      await _apiClient.post<Map<String, dynamic>>('/match/cancel');
    } catch (_) {}
  }

  bool get _hasSession {
    final token = StorageService.getToken();
    return token != null && token.isNotEmpty;
  }

  User _mapUser(Map<String, dynamic> json) {
    return User(
      id: (json['userId'] ?? json['id']).toString(),
      uid: (json['uid'] ?? '').toString(),
      nickname: (json['nickname'] ?? '神秘人').toString(),
      avatar: _mapAvatar(json['avatar']?.toString()),
      distance: (json['distance'] ?? '附近').toString(),
      status: (json['status'] ?? '想找人聊聊').toString(),
      isOnline: json['isOnline'] != false,
    );
  }

  String _mapAvatar(String? avatar) {
    switch (avatar) {
      case 'avatar_1':
        return '😄';
      case 'avatar_2':
        return '🙂';
      case 'avatar_3':
        return '🫧';
      default:
        return avatar?.isNotEmpty == true ? avatar! : '👤';
    }
  }
}
