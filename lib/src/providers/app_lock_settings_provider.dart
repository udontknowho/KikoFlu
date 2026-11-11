import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回到前台验证的开关。
///
/// 只存一个布尔量。锁的状态本身不落盘：进程活着才锁，
/// 目的是挡住"别人拿起手机翻你的库"，不是防调试。
class AppLockSettings {
  final bool enabled;

  const AppLockSettings({this.enabled = false});

  AppLockSettings copyWith({bool? enabled}) {
    return AppLockSettings(enabled: enabled ?? this.enabled);
  }
}

class AppLockSettingsNotifier extends StateNotifier<AppLockSettings> {
  static const String _enabledKey = 'app_lock_enabled';

  bool _changedLocally = false;

  AppLockSettingsNotifier() : super(const AppLockSettings()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || _changedLocally) return;
      state = AppLockSettings(enabled: prefs.getBool(_enabledKey) ?? false);
    } catch (_) {
      state = const AppLockSettings();
    }
  }

  Future<void> setEnabled(bool value) async {
    _changedLocally = true;
    state = state.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }
}

final appLockSettingsProvider =
    StateNotifierProvider<AppLockSettingsNotifier, AppLockSettings>(
  (ref) => AppLockSettingsNotifier(),
);
