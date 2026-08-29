package com.wizzling.tx_browser

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * AcquisitionBridge handles:
 * 1. Google Play Install Referrer API queries.
 * 2. Android Home-Screen Pinned Shortcuts (via ShortcutManagerCompat).
 * 3. Deep link intent dispatching.
 */
class AcquisitionBridge(
    private val context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AcquisitionBridge"
    }

    private var initialDeepLink: String? = null

    fun setInitialIntent(intent: Intent?) {
        val dataString = intent?.dataString
        val extraTargetUrl = intent?.getStringExtra("target_url")
        initialDeepLink = extraTargetUrl ?: dataString
    }

    fun onNewIntent(intent: Intent?) {
        val dataString = intent?.dataString
        val extraTargetUrl = intent?.getStringExtra("target_url")
        val link = extraTargetUrl ?: dataString
        if (!link.isNullOrEmpty()) {
            Handler(Looper.getMainLooper()).post {
                channel.invokeMethod("onDeepLinkReceived", link)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstallReferrer" -> {
                fetchInstallReferrer(result)
            }

            "requestPinShortcut" -> {
                val url = call.argument<String>("url")
                val title = call.argument<String>("title") ?: "Web Site"
                val shortcutId = call.argument<String>("shortcutId") ?: ("tx_shortcut_" + (url?.hashCode() ?: System.currentTimeMillis()))

                if (url.isNullOrEmpty()) {
                    result.error("INVALID_URL", "Shortcut URL cannot be empty", null)
                    return
                }

                try {
                    val success = requestPinShortcut(url, title, shortcutId)
                    result.success(success)
                } catch (e: Exception) {
                    Log.e(TAG, "Error pinning shortcut: ${e.message}")
                    result.error("PIN_FAILED", e.localizedMessage, null)
                }
            }

            "isPinShortcutSupported" -> {
                try {
                    val supported = ShortcutManagerCompat.isRequestPinShortcutSupported(context)
                    result.success(supported)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

            "getInitialDeepLink" -> {
                result.success(initialDeepLink)
            }

            else -> result.notImplemented()
        }
    }

    private fun fetchInstallReferrer(result: MethodChannel.Result) {
        var isResultReturned = false
        val mainHandler = Handler(Looper.getMainLooper())

        val referrerClient = try {
            InstallReferrerClient.newBuilder(context).build()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to build InstallReferrerClient: ${e.message}")
            result.success(null)
            return
        }

        // Safety timeout runnable (3.0 seconds maximum) to ensure startup is never blocked
        val timeoutRunnable = Runnable {
            if (!isResultReturned) {
                isResultReturned = true
                try {
                    referrerClient.endConnection()
                } catch (_: Exception) {}
                Log.d(TAG, "InstallReferrer query timed out")
                result.success(null)
            }
        }
        mainHandler.postDelayed(timeoutRunnable, 3000)

        try {
            referrerClient.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    mainHandler.removeCallbacks(timeoutRunnable)
                    if (isResultReturned) return
                    isResultReturned = true

                    when (responseCode) {
                        InstallReferrerClient.InstallReferrerResponse.OK -> {
                            try {
                                val responseDetails = referrerClient.installReferrer
                                val referrerMap = hashMapOf<String, Any?>(
                                    "installReferrer" to responseDetails.installReferrer,
                                    "referrerClickTimestampSeconds" to responseDetails.referrerClickTimestampSeconds,
                                    "installBeginTimestampSeconds" to responseDetails.installBeginTimestampSeconds
                                )
                                referrerClient.endConnection()
                                result.success(referrerMap)
                            } catch (e: Exception) {
                                Log.w(TAG, "Error reading responseDetails: ${e.message}")
                                try { referrerClient.endConnection() } catch (_: Exception) {}
                                result.success(null)
                            }
                        }

                        InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED -> {
                            Log.d(TAG, "InstallReferrer FEATURE_NOT_SUPPORTED")
                            try { referrerClient.endConnection() } catch (_: Exception) {}
                            result.success(null)
                        }

                        InstallReferrerClient.InstallReferrerResponse.SERVICE_UNAVAILABLE -> {
                            Log.d(TAG, "InstallReferrer SERVICE_UNAVAILABLE")
                            try { referrerClient.endConnection() } catch (_: Exception) {}
                            result.success(null)
                        }

                        InstallReferrerClient.InstallReferrerResponse.DEVELOPER_ERROR -> {
                            Log.d(TAG, "InstallReferrer DEVELOPER_ERROR")
                            try { referrerClient.endConnection() } catch (_: Exception) {}
                            result.success(null)
                        }

                        else -> {
                            Log.d(TAG, "InstallReferrer unknown response code: $responseCode")
                            try { referrerClient.endConnection() } catch (_: Exception) {}
                            result.success(null)
                        }
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    Log.d(TAG, "InstallReferrer service disconnected")
                }
            })
        } catch (e: Exception) {
            mainHandler.removeCallbacks(timeoutRunnable)
            if (!isResultReturned) {
                isResultReturned = true
                Log.w(TAG, "Error starting connection: ${e.message}")
                result.success(null)
            }
        }
    }

    private fun requestPinShortcut(url: String, title: String, shortcutId: String): Boolean {
        if (!ShortcutManagerCompat.isRequestPinShortcutSupported(context)) {
            Log.w(TAG, "Pin shortcut is not supported by launcher")
            return false
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse(url)
            putExtra("target_url", url)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pinShortcutInfo = ShortcutInfoCompat.Builder(context, shortcutId)
            .setIcon(IconCompat.createWithResource(context, R.mipmap.ic_launcher))
            .setShortLabel(title.take(25))
            .setLongLabel(title.take(50))
            .setIntent(launchIntent)
            .build()

        return ShortcutManagerCompat.requestPinShortcut(context, pinShortcutInfo, null)
    }
}
