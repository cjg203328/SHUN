import 'package:dio/dio.dart';

import '../config/app_env.dart';
import '../core/network/api_exception.dart';
import 'storage_service.dart';

class ApiClient {
  ApiClient._internal()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppEnv.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = StorageService.getToken();
          final shouldAttachToken = options.extra['authRequired'] != false;
          if (shouldAttachToken && token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (await _tryRefreshAndRetry(error, handler)) {
            return;
          }
          handler.next(_normalizeDioError(error));
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  final Dio _dio;
  Future<bool>? _refreshingFuture;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authRequired = true,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: Options(extra: {'authRequired': authRequired}),
    );
    return _unwrap<T>(response.data);
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool authRequired = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(extra: {'authRequired': authRequired}),
    );
    return _unwrap<T>(response.data);
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    bool authRequired = true,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(extra: {'authRequired': authRequired}),
    );
    return _unwrap<T>(response.data);
  }

  Future<T> delete<T>(
    String path, {
    Object? data,
    bool authRequired = true,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(extra: {'authRequired': authRequired}),
    );
    return _unwrap<T>(response.data);
  }

  T _unwrap<T>(Map<String, dynamic>? payload) {
    if (payload == null) {
      throw const ApiException(code: 'EMPTY_RESPONSE', message: '服务返回为空');
    }

    if (payload['success'] == true) {
      return payload['data'] as T;
    }

    throw ApiException(
      code: (payload['code'] ?? 'INVALID_RESPONSE').toString(),
      message: (payload['message'] ?? '服务返回异常').toString(),
      detail: payload['detail']?.toString(),
    );
  }

  Future<bool> _tryRefreshAndRetry(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = error.response?.statusCode;
    final options = error.requestOptions;
    final isRefreshRequest = options.path.endsWith('/auth/refresh');
    final canRetry = options.extra['_retried'] != true;
    final authRequired = options.extra['authRequired'] != false;

    if (statusCode != 401 || isRefreshRequest || !canRetry || !authRequired) {
      return false;
    }

    final refreshed = await _refreshAccessToken();
    if (!refreshed) {
      return false;
    }

    final nextToken = StorageService.getToken();
    if (nextToken == null || nextToken.isEmpty) {
      return false;
    }

    final retryOptions = Options(
      method: options.method,
      headers: {...options.headers, 'Authorization': 'Bearer $nextToken'},
      responseType: options.responseType,
      contentType: options.contentType,
      extra: {...options.extra, '_retried': true},
    );

    final response = await _dio.request<Map<String, dynamic>>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: retryOptions,
    );
    handler.resolve(response);
    return true;
  }

  Future<bool> _refreshAccessToken() {
    final running = _refreshingFuture;
    if (running != null) {
      return running;
    }

    final refreshFuture = _performRefresh();
    _refreshingFuture = refreshFuture;
    refreshFuture.whenComplete(() {
      if (identical(_refreshingFuture, refreshFuture)) {
        _refreshingFuture = null;
      }
    });
    return refreshFuture;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = StorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'authRequired': false, '_retried': true}),
      );

      final data = _unwrap<Map<String, dynamic>>(response.data);
      final nextAccessToken = data['accessToken']?.toString();
      final nextRefreshToken = data['refreshToken']?.toString();
      if (nextAccessToken == null || nextRefreshToken == null) {
        return false;
      }

      await StorageService.saveToken(nextAccessToken);
      await StorageService.saveRefreshToken(nextRefreshToken);
      return true;
    } on DioException {
      await StorageService.clearAuth();
      return false;
    } on ApiException {
      await StorageService.clearAuth();
      return false;
    }
  }

  DioException _normalizeDioError(DioException error) {
    if (error.error is ApiException) {
      return error;
    }

    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      return error.copyWith(
        error: ApiException(
          code: (responseData['code'] ?? 'REQUEST_FAILED').toString(),
          message: (responseData['message'] ?? '请求失败').toString(),
          detail: responseData['detail']?.toString(),
          statusCode: error.response?.statusCode,
        ),
      );
    }

    return error.copyWith(
      error: ApiException(
        code: 'NETWORK_ERROR',
        message: '网络连接失败',
        detail: error.message,
        statusCode: error.response?.statusCode,
      ),
    );
  }
}
