import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_lock_settings_provider.dart';
import '../services/app_lock_service.dart';

/// 盖在所有路由最上面的一层锁。
///
/// 挂在 MaterialApp.builder 里，所以播放页、设置页、对话框全被这层盖住，
/// 不是只遮住某一个页面。退到后台就上锁，回前台先验证，过了才露出内容。
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _prompting = false;
  bool _available = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final available = await AppLockService.isAvailable();
    if (!mounted) return;
    setState(() => _available = available);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isAndroid || !_available) return;
    if (!ref.read(appLockSettingsProvider).enabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // 真进后台才上锁。inactive 在下拉通知栏、弹系统对话框时也会来，
      // 拿它当判据会锁得太勤。
      if (!_locked) {
        setState(() => _locked = true);
      }
    } else if (state == AppLifecycleState.resumed && _locked) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_prompting) return;
    _prompting = true;
    final unlocked = await AppLockService.authenticate();
    _prompting = false;
    if (!mounted) return;
    if (unlocked) {
      setState(() => _locked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(appLockSettingsProvider).enabled;
    final covering = enabled && _available && _locked;

    return Stack(
      children: [
        widget.child,
        if (covering)
          Positioned.fill(
            child: _AppLockCover(onUnlock: _authenticate),
          ),
      ],
    );
  }
}

/// 全屏不透明遮罩。内容盖住，点击吃掉，只留一个解锁按钮。
class _AppLockCover extends StatelessWidget {
  final VoidCallback onUnlock;

  const _AppLockCover({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Material(
        color: colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '已锁定',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '验证指纹或锁屏密码后继续',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('解锁'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
