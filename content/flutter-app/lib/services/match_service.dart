import '../repositories/app_data_repository.dart';

class MatchService {
  MatchService({AppDataRepository? repository})
      : _repository = repository ?? AppDataRepository.instance;

  final AppDataRepository _repository;

  static const int dailyQuota = 20;

  MatchStateSnapshot loadState() {
    return _repository.loadMatchState();
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
    final shouldReset =
        lastReset == null || (!hasSameDate && now.hour >= 9);
    if (!shouldReset) return currentCount;

    await _repository.saveMatchCount(dailyQuota);
    await _repository.saveLastResetDate(now);
    return dailyQuota;
  }

  Future<void> saveMatchCount(int count) async {
    await _repository.saveMatchCount(count);
  }
}
