package com.sunliao.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "sunliao/app_meta"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getFirstInstallTime") {
                val firstInstallTime = packageManager
                    .getPackageInfo(packageName, 0)
                    .firstInstallTime
                result.success(firstInstallTime)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "sunliao/screen_security"
        ).setMethodCallHandler { call, result ->
            if (call.method == "setSecureScreen") {
                val enabled = call.argument<Boolean>("enabled") ?: false
                runOnUiThread {
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}


