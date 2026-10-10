package com.iqballab.focusflow

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * FlutterFragmentActivity (not FlutterActivity) because local_auth's
 * BiometricPrompt needs a FragmentActivity.
 *
 * Hosts the `focusflow/text_scanner` channel: on-device OCR for Quick Scan
 * with ML Kit (Play-services model). iOS implements the same channel with
 * Apple Vision — see ios/Runner/TextScannerPlugin.swift.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusflow/text_scanner")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognizeText" -> {
                        val path = call.argument<String>("path")
                        if (path == null || !File(path).exists()) {
                            result.error("bad_path", "Image not found", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                            TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                                .process(image)
                                .addOnSuccessListener { text -> result.success(text.text) }
                                .addOnFailureListener { e -> result.error("ocr_failed", e.message, null) }
                        } catch (e: Exception) {
                            result.error("ocr_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
