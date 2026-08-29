package com.wizzling.tx_browser

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val DOWNLOAD_CHANNEL = "com.wizzling.tx_browser/downloads"
    private val ACQUISITION_CHANNEL = "com.wizzling.tx_browser/acquisition"

    private var acquisitionBridge: AcquisitionBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val downloadBridge = DownloadManagerBridge(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL)
            .setMethodCallHandler(downloadBridge)

        val acquisitionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACQUISITION_CHANNEL)
        val bridge = AcquisitionBridge(applicationContext, acquisitionChannel)
        bridge.setInitialIntent(intent)
        acquisitionBridge = bridge
        acquisitionChannel.setMethodCallHandler(bridge)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        acquisitionBridge?.onNewIntent(intent)
    }
}
