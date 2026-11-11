import 'dart:io';

import 'package:flutter/services.dart';

/// 回到前台验证的原生桥。
///
/// 只有 Android 有实现，其他平台 [isAvailable] 恒为 false，设置里就不显示开关。
/// 原生侧走 framework 的 BiometricPrompt，允许指纹、面容和锁屏密码。
class AppLockService {
  static const MethodChannel _channel =
      MethodChannel('com.meteor.kikoeruflutter/app_lock');

  static bool _checked = false;
  static bool _available = false;

  /// 设备有没有可用的验证方式（指纹 / 面容 / 锁屏密码）。
  ///
  /// 结果缓存一次：设备能力在运行期不会变。
  static Future<bool> isAvailable() async {
    if (!Platform.isAndroid) {
      return false;
    }
    if (_checked) {
      return _available;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      _available = result ?? false;
    } catch (_) {
      _available = false;
    }
    _checked = true;
    return _available;
  }

  /// 弹一次系统验证。通过返回 true，取消或识别失败都返回 false。
  static Future<bool> authenticate() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('authenticate');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
