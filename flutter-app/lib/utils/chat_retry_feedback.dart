import '../core/feedback/app_feedback.dart';
import 'chat_delivery_state.dart';

AppErrorCode deliveryRetryErrorCodeFor(
  ChatDeliveryFailureState failureState,
) {
  return switch (failureState) {
    ChatDeliveryFailureState.threadExpired => AppErrorCode.unknown,
    ChatDeliveryFailureState.blockedRelation => AppErrorCode.blocked,
    ChatDeliveryFailureState.imageUploadPreparationFailed =>
      AppErrorCode.sendFailed,
    ChatDeliveryFailureState.imageUploadInterrupted => AppErrorCode.sendFailed,
    ChatDeliveryFailureState.imageUploadTokenInvalid => AppErrorCode.sendFailed,
    ChatDeliveryFailureState.imageUploadFileTooLarge =>
      AppErrorCode.invalidInput,
    ChatDeliveryFailureState.imageUploadUnsupportedFormat =>
      AppErrorCode.invalidInput,
    ChatDeliveryFailureState.networkIssue => AppErrorCode.sendFailed,
    ChatDeliveryFailureState.imageReselectRequired => AppErrorCode.invalidInput,
    ChatDeliveryFailureState.retryUnavailable => AppErrorCode.unknown,
    ChatDeliveryFailureState.retryable => AppErrorCode.sendFailed,
  };
}

String deliveryRetryErrorDetailFor(
  ChatDeliveryFailureState failureState, {
  required bool isImage,
}) {
  return switch (failureState) {
    ChatDeliveryFailureState.threadExpired => '会话已过期，请返回列表重试',
    ChatDeliveryFailureState.blockedRelation => '当前关系受限，暂不能发送',
    ChatDeliveryFailureState.imageUploadPreparationFailed => '图片准备失败，请重试',
    ChatDeliveryFailureState.imageUploadInterrupted =>
      isImage ? '网络中断，请重试图片' : '网络中断，请重试',
    ChatDeliveryFailureState.imageUploadTokenInvalid => '上传凭证失效，请重试',
    ChatDeliveryFailureState.imageUploadFileTooLarge => '图片过大，请换一张',
    ChatDeliveryFailureState.imageUploadUnsupportedFormat => '格式不支持，请换张图片',
    ChatDeliveryFailureState.networkIssue =>
      isImage ? '网络异常，请重试图片' : '网络异常，请重试消息',
    ChatDeliveryFailureState.imageReselectRequired => '原图失效，请重选图片',
    ChatDeliveryFailureState.retryUnavailable => '当前不可重试，请确认会话状态',
    ChatDeliveryFailureState.retryable => isImage ? '图片发送失败，请重试' : '消息发送失败，请重试',
  };
}
