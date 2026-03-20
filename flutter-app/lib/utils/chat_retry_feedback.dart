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
    ChatDeliveryFailureState.threadExpired =>
      isImage ? '这条图片消息所在的会话已经到期，当前不能继续重试。' : '这条消息所在的会话已经到期，当前不能继续重试。',
    ChatDeliveryFailureState.blockedRelation =>
      isImage ? '你和对方当前处于拉黑关系，图片暂时不能继续发送。' : '你和对方当前处于拉黑关系，消息暂时不能继续发送。',
    ChatDeliveryFailureState.imageUploadPreparationFailed =>
      '图片上传准备失败，服务端暂时无法完成上传准备，请稍后重新发送。',
    ChatDeliveryFailureState.imageUploadInterrupted =>
      '图片上传过程中已中断，建议检查网络后重新投递。',
    ChatDeliveryFailureState.imageUploadTokenInvalid =>
      '图片上传凭证已失效，再试一次就会重新刷新凭证后再提交。',
    ChatDeliveryFailureState.imageUploadFileTooLarge =>
      '当前图片已超过上传大小限制，请更换更小的图片或使用压缩图后再发送。',
    ChatDeliveryFailureState.imageUploadUnsupportedFormat =>
      '当前文件没有通过图片校验，请重新选择常见图片格式后再发送。',
    ChatDeliveryFailureState.networkIssue =>
      isImage ? '网络连接不稳定，建议检查网络后重新投递图片。' : '网络连接不稳定，建议检查网络后重新发送消息。',
    ChatDeliveryFailureState.imageReselectRequired => '图片发送失败，原图失效后请重新选择图片再发送。',
    ChatDeliveryFailureState.retryUnavailable =>
      isImage ? '图片当前暂不可重试，请先确认会话状态后再处理。' : '消息当前暂不可重试，请先确认会话状态后再处理。',
    ChatDeliveryFailureState.retryable =>
      isImage ? '图片发送失败，请检查网络后立即重试。' : '消息发送失败，请检查网络后立即重试。',
  };
}
