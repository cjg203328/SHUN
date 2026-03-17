import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/services/chat_service.dart';
import 'package:sunliao/services/media_upload_service.dart';

void main() {
  test('normalizeChatImageUploadFailure should map oversized upload error', () {
    final normalized = normalizeChatImageUploadFailure(
      stage: ChatImageUploadFailureStage.upload,
      failure: const ChatRequestFailure(
        code: 'INVALID_INPUT',
        message: 'Image file is too large',
        statusCode: 400,
      ),
    );

    expect(normalized.code, 'IMAGE_UPLOAD_TOO_LARGE');
  });

  test(
      'normalizeChatImageUploadFailure should map unsupported format upload error',
      () {
    final normalized = normalizeChatImageUploadFailure(
      stage: ChatImageUploadFailureStage.upload,
      failure: const ChatRequestFailure(
        code: 'INVALID_INPUT',
        message: 'Only image upload is allowed',
        statusCode: 400,
      ),
    );

    expect(normalized.code, 'IMAGE_UPLOAD_UNSUPPORTED_FORMAT');
  });

  test('normalizeChatImageUploadFailure should map invalid upload token error',
      () {
    final normalized = normalizeChatImageUploadFailure(
      stage: ChatImageUploadFailureStage.upload,
      failure: const ChatRequestFailure(
        code: 'INVALID_INPUT',
        message: 'Invalid upload token',
        statusCode: 400,
      ),
    );

    expect(normalized.code, 'UPLOAD_TOKEN_INVALID');
  });

  test('normalizeChatImageUploadFailure should keep unrelated errors unchanged',
      () {
    const failure = ChatRequestFailure(
      code: 'NETWORK_ERROR',
      message: 'Socket transport unavailable',
    );
    final normalized = normalizeChatImageUploadFailure(
      stage: ChatImageUploadFailureStage.upload,
      failure: failure,
    );

    expect(normalized.code, failure.code);
    expect(normalized.message, failure.message);
  });
}
