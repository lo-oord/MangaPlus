package com.mangaplus.app

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.mangaplus.app/connectivity",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            private var manager: ConnectivityManager? = null
            private var callback: ConnectivityManager.NetworkCallback? = null
            private var sink: EventChannel.EventSink? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val connectivity = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
                manager = connectivity
                sink = events
                val networkCallback = object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) = emitStatus()
                    override fun onLost(network: Network) = emitStatus()
                    override fun onCapabilitiesChanged(
                        network: Network,
                        networkCapabilities: NetworkCapabilities,
                    ) = emitStatus()
                }
                callback = networkCallback
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    connectivity.registerDefaultNetworkCallback(networkCallback)
                } else {
                    connectivity.registerNetworkCallback(
                        NetworkRequest.Builder()
                            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                            .build(),
                        networkCallback,
                    )
                }
                emitStatus()
            }

            override fun onCancel(arguments: Any?) {
                val activeManager = manager
                val activeCallback = callback
                if (activeManager != null && activeCallback != null) {
                    runCatching { activeManager.unregisterNetworkCallback(activeCallback) }
                }
                manager = null
                callback = null
                sink = null
            }

            private fun emitStatus() {
                val activeManager = manager ?: return
                val network = activeManager.activeNetwork
                val capabilities = network?.let(activeManager::getNetworkCapabilities)
                val hasInternet = capabilities != null &&
                    capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                    capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                sink?.success(hasInternet)
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.mangaplus.app/mknov_font_decoder",
        ).setMethodCallHandler { call, result ->
            if (call.method != "decodeChapterBody") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val text = call.argument<String>("text")
            val font = call.argument<ByteArray>("font")
            if (text == null || font == null || font.isEmpty()) {
                result.error("INVALID_MKNOV_FONT_INPUT", "Missing chapter text or WOFF2 font bytes.", null)
                return@setMethodCallHandler
            }

            Thread {
                try {
                    val decodedFont = Woff2Decoder.decode(font)
                    val decodedText = buildString(text.length) {
                        for (character in text) {
                            val glyphId = decodedFont.cmap[character.code]
                            val glyphName = glyphId?.let(decodedFont.post::get)
                            val decodedCharacter = glyphName?.let(::decodeGlyphName)
                            append(decodedCharacter ?: character)
                        }
                    }
                    runOnUiThread { result.success(decodedText) }
                } catch (error: Throwable) {
                    runOnUiThread {
                        result.error(
                            "MKNOV_FONT_DECODE_FAILED",
                            error.message ?: "Could not decode the protected chapter font.",
                            null,
                        )
                    }
                }
            }.start()
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.mangaplus.app/system",
        ).setMethodCallHandler { call, result ->
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            when (call.method) {
                "isBatteryOptimizationIgnored" -> {
                    result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                }
                "requestBatteryOptimizationExemption" -> {
                    if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                        startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
