import 'package:flutter/foundation.dart';

enum AppRuntimeEnv {
  demo,
  development,
  staging,
  production,
}

class AppEnv {
  AppEnv._();

  static const String _appEnvDefine = String.fromEnvironment(
    'SUNLIAO_APP_ENV',
    defaultValue: '',
  );
  static const String _apiBaseUrlDefine = String.fromEnvironment(
    'SUNLIAO_API_BASE_URL',
    defaultValue: '',
  );
  static const String _mediaBaseUrlDefine = String.fromEnvironment(
    'SUNLIAO_MEDIA_BASE_URL',
    defaultValue: '',
  );
  static const bool _releaseBuildDefine = bool.fromEnvironment(
    'SUNLIAO_RELEASE_BUILD',
    defaultValue: false,
  );

  static bool get isReleaseBuild => _releaseBuildDefine;

  static AppRuntimeEnv get runtimeEnv {
    final normalized = _appEnvDefine.trim().toLowerCase();
    switch (normalized) {
      case 'demo':
        return AppRuntimeEnv.demo;
      case 'dev':
      case 'development':
        return AppRuntimeEnv.development;
      case 'staging':
        return AppRuntimeEnv.staging;
      case 'prod':
      case 'production':
        return AppRuntimeEnv.production;
      default:
        return isReleaseBuild ? AppRuntimeEnv.production : AppRuntimeEnv.demo;
    }
  }

  static String get runtimeLabel => switch (runtimeEnv) {
        AppRuntimeEnv.demo => 'demo',
        AppRuntimeEnv.development => 'development',
        AppRuntimeEnv.staging => 'staging',
        AppRuntimeEnv.production => 'production',
      };

  static bool get isDemoEnv => runtimeEnv == AppRuntimeEnv.demo;
  static bool get isDevelopmentEnv => runtimeEnv == AppRuntimeEnv.development;
  static bool get isStagingEnv => runtimeEnv == AppRuntimeEnv.staging;
  static bool get isProductionEnv => runtimeEnv == AppRuntimeEnv.production;

  static bool get allowLocalDemoFallbacks => isDemoEnv || isDevelopmentEnv;
  static bool get allowLocalAuthFallbacks => isDemoEnv;
  static bool get allowMockMatchPool => isDemoEnv || isDevelopmentEnv;
  static bool get allowMockChatReplies => isDemoEnv;
  static bool get allowDayTheme => false;

  static String get apiBaseUrl {
    final configured = _apiBaseUrlDefine.trim();
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:3000/api/v1';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api/v1';
    }

    return 'http://127.0.0.1:3000/api/v1';
  }

  static String get socketBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portPart';
  }

  static String? get mediaBaseUrl {
    final value = _mediaBaseUrlDefine.trim();
    if (value.isNotEmpty) {
      return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    }

    return '$socketBaseUrl/media';
  }

  static String resolveMediaUrl(String imageKey) {
    if (imageKey.startsWith('http://') || imageKey.startsWith('https://')) {
      return imageKey;
    }

    if (_isLocalFilePath(imageKey)) {
      return imageKey;
    }

    final baseUrl = mediaBaseUrl;
    if (baseUrl == null || imageKey.isEmpty) {
      return imageKey;
    }

    final normalizedKey =
        imageKey.startsWith('/') ? imageKey.substring(1) : imageKey;
    return '$baseUrl/$normalizedKey';
  }

  static bool _isLocalFilePath(String path) {
    if (path.startsWith('file://')) {
      return true;
    }
    final windowsDrivePattern = RegExp(r'^[A-Za-z]:[\\/]');
    if (windowsDrivePattern.hasMatch(path)) {
      return true;
    }
    return path.startsWith('\\');
  }
}
