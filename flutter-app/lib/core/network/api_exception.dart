class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final String? detail;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.detail,
  });

  String get userMessage => detail == null || detail!.trim().isEmpty
      ? message
      : '${message.trim()}：${detail!.trim()}';

  @override
  String toString() {
    return 'ApiException(code: $code, statusCode: $statusCode, message: $message, detail: $detail)';
  }
}
