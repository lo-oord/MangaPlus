package com.mangaplus.app

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
            }
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
