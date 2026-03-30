import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/core/feedback/app_feedback.dart';
import 'package:sunliao/utils/chat_delivery_state.dart';
import 'package:sunliao/utils/chat_retry_feedback.dart';

void main() {
  test('deliveryRetryErrorDetailFor keeps retryable text actionable', () {
    expect(
      deliveryRetryErrorDetailFor(
        ChatDeliveryFailureState.retryable,
        isImage: false,
      ),
      '消息发送失败，请重试',
    );
    expect(
      deliveryRetryErrorDetailFor(
        ChatDeliveryFailureState.retryable,
        isImage: true,
      ),
      '图片发送失败，请重试',
    );
  });

  test('deliveryRetryErrorCodeFor keeps duplicate retry errors in sendFailed',
      () {
    expect(
      deliveryRetryErrorCodeFor(ChatDeliveryFailureState.retryable),
      AppErrorCode.sendFailed,
    );
    expect(
      deliveryRetryErrorCodeFor(ChatDeliveryFailureState.networkIssue),
      AppErrorCode.sendFailed,
    );
  });
}
