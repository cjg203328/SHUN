import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/services/chat_delivery_stats_service.dart';

void main() {
  test('loadSnapshot should normalize known event labels and tags by code', () {
    final service = ChatDeliveryStatsService();

    service.loadSnapshot(<String, dynamic>{
      'counters': <String, int>{
        ChatDeliveryStatsService.imageFailedKey: 1,
        ChatDeliveryStatsService.imageReselectRequiredKey: 1,
      },
      'recentEvents': <Map<String, dynamic>>[
        <String, dynamic>{
          'code': ChatDeliveryStatsService.imageFailedKey,
          'label': '鍥剧墖鍙戦€佸け璐?',
          'tagLabel': '鍥剧墖',
          'timestamp': DateTime.now()
              .subtract(const Duration(minutes: 2))
              .toIso8601String(),
          'isError': true,
        },
        <String, dynamic>{
          'code': ChatDeliveryStatsService.imageReselectRequiredKey,
          'label': '鍘熷浘澶辨晥锛岄渶閲嶉€夊浘鐗?',
          'tagLabel': '鍥剧墖',
          'timestamp': DateTime.now().toIso8601String(),
          'isError': true,
        },
      ],
    });

    expect(service.recentEvents.first.label, '原图失效，需重选图片');
    expect(service.recentEvents.first.tagLabel, '图片');
    expect(service.recentEvents.last.label, '图片发送失败');
    expect(service.recentEvents.last.tagLabel, '图片');
  });

  test('record methods should emit canonical labels and tags', () {
    final service = ChatDeliveryStatsService();

    service.recordRetryRequested();
    service.recordRetrySucceeded();
    service.recordTextFailed();

    expect(service.counters[ChatDeliveryStatsService.retriesRequestedKey], 1);
    expect(service.counters[ChatDeliveryStatsService.retriesSucceededKey], 1);
    expect(service.counters[ChatDeliveryStatsService.textFailedKey], 1);
    expect(service.recentEvents[0].label, '文本发送失败');
    expect(service.recentEvents[0].tagLabel, '文本');
    expect(service.recentEvents[1].label, '重试成功，已送达');
    expect(service.recentEvents[1].tagLabel, '重试');
    expect(service.recentEvents[2].label, '已发起重试');
    expect(service.recentEvents[2].tagLabel, '重试');
  });
}
