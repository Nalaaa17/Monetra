package com.monetra.monetra

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.monetra.monetra/share"
        private const val EVENT_CHANNEL = "com.monetra.monetra/share/events"
    }

    private var pendingShare: Map<String, String?>? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingShare = extractSharePayload(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialShare" -> {
                        val payload = pendingShare
                        pendingShare = null
                        result.success(payload)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = extractSharePayload(intent) ?: return
        val sink = eventSink
        if (sink != null) {
            sink.success(payload)
        } else {
            pendingShare = payload
        }
    }

    private fun extractSharePayload(intent: Intent?): Map<String, String?>? {
        if (intent?.action != Intent.ACTION_SEND) return null

        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        val imageUri = readStreamUri(intent)
        val imagePath = imageUri?.let { copyUriToCache(it) }

        if (imagePath == null && sharedText.isNullOrBlank()) {
            return null
        }

        return mapOf(
            "imagePath" to imagePath,
            "text" to sharedText
        )
    }

    @Suppress("DEPRECATION")
    private fun readStreamUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val mime = contentResolver.getType(uri)?.lowercase() ?: ""
            val ext = when {
                mime.contains("png") -> ".png"
                mime.contains("webp") -> ".webp"
                else -> ".jpg"
            }
            val dir = File(cacheDir, "shared_receipts")
            if (!dir.exists()) {
                dir.mkdirs()
            }
            val outFile = File(dir, "receipt_${System.currentTimeMillis()}$ext")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            outFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }
}
