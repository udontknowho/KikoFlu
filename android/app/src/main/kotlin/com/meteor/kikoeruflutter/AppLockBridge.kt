package com.meteor.kikoeruflutter

import android.app.Activity
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 回到前台验证的原生侧。
 *
 * 用 framework 的 BiometricPrompt（API 28+），不引 androidx.biometric，
 * 所以宿主 Activity 不需要是 FragmentActivity。
 *
 * 允许 BIOMETRIC_WEAK | DEVICE_CREDENTIAL：指纹、面容、锁屏密码都能解。
 * 设备上两样都没有时 isAvailable 返回 false，Dart 侧就不显示开关。
 */
class AppLockBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.meteor.kikoeruflutter/app_lock"
        private const val TITLE = "解锁 KikoFlu"
        private const val SUBTITLE = "验证指纹或锁屏密码"
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    /** 验证进行中，防止重复弹窗 */
    private var prompting = false

    /** 只为了防止 CancellationSignal 被回收 */
    private var signal: CancellationSignal? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        signal?.cancel()
        signal = null
        prompting = false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(isAvailable())
            "authenticate" -> authenticate(result)
            else -> result.notImplemented()
        }
    }

    /** 设备有没有可用的验证方式。没有就整个开关没意义。 */
    private fun isAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return false
        }
        val manager = activity.getSystemService(BiometricManager::class.java)
            ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            manager.canAuthenticate(
                BiometricManager.Authenticators.BIOMETRIC_WEAK or
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL
            ) == BiometricManager.BIOMETRIC_SUCCESS
        } else {
            manager.canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
        }
    }

    private fun authenticate(result: MethodChannel.Result) {
        if (prompting) {
            result.success(false)
            return
        }
        if (!isAvailable()) {
            result.success(false)
            return
        }

        val cancellation = CancellationSignal()
        signal = cancellation
        prompting = true

        val builder = BiometricPrompt.Builder(activity)
            .setTitle(TITLE)
            .setSubtitle(SUBTITLE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_WEAK or
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setDeviceCredentialAllowed(true)
        }

        builder.build().authenticate(
            cancellation,
            activity.mainExecutor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    authResult: BiometricPrompt.AuthenticationResult
                ) {
                    finish(true, result)
                }

                override fun onAuthenticationError(
                    errorCode: Int,
                    errString: CharSequence
                ) {
                    // 指纹和锁屏密码都没了：不把用户挡在自己的 App 外面
                    if (!isAvailable()) {
                        finish(true, result)
                        return
                    }
                    // 其余一律按没过处理，遮罩留在原地，等用户再点一次
                    finish(false, result)
                }

                override fun onAuthenticationFailed() {
                    // 单次识别失败不算错误，系统会让用户继续试，这里不动结果
                }
            }
        )
    }

    private fun finish(success: Boolean, result: MethodChannel.Result) {
        prompting = false
        signal = null
        result.success(success)
    }
}
