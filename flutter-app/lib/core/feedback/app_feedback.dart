import 'package:flutter/material.dart';
import '../../widgets/app_toast.dart';

enum AppErrorCode {
  permissionDenied,
  sendFailed,
  unlockRequired,
  blocked,
  invalidInput,
  notSupported,
  unknown,
}

enum AppToastCode {
  enabled,
  disabled,
  saved,
  sent,
  deleted,
  copied,
}

class AppFeedback {
  static String errorText(
    AppErrorCode code, {
    String? detail,
  }) {
    switch (code) {
      case AppErrorCode.permissionDenied:
        return '未开启权限，请先授权';
      case AppErrorCode.sendFailed:
        return detail ?? '发送失败，请重试';
      case AppErrorCode.unlockRequired:
        return detail ?? '继续互动解锁该功能';
      case AppErrorCode.blocked:
        return detail ?? '当前不可操作，请先解除拉黑';
      case AppErrorCode.invalidInput:
        return detail ?? '输入有误，请检查后重试';
      case AppErrorCode.notSupported:
        return detail ?? '当前不支持该操作';
      case AppErrorCode.unknown:
        return detail ?? '操作失败，请重试';
    }
  }

  static String toastText(AppToastCode code, {String? subject}) {
    switch (code) {
      case AppToastCode.enabled:
        return '已开启${subject ?? '功能'}';
      case AppToastCode.disabled:
        return '已关闭${subject ?? '功能'}';
      case AppToastCode.saved:
        return '${subject ?? '内容'}已保存';
      case AppToastCode.sent:
        return '${subject ?? '内容'}已发送';
      case AppToastCode.deleted:
        return '${subject ?? '内容'}已删除';
      case AppToastCode.copied:
        return '已复制';
    }
  }

  static void showError(
    BuildContext context,
    AppErrorCode code, {
    String? detail,
  }) {
    AppToast.show(context, errorText(code, detail: detail), isError: true);
  }

  static void showToast(
    BuildContext context,
    AppToastCode code, {
    String? subject,
  }) {
    AppToast.show(context, toastText(code, subject: subject));
  }
}
