package com.eslamholiday.eslam_office

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eslam_money/gallery").setMethodCallHandler { call, result ->
            if (call.method != "saveImage") {
                result.notImplemented()
            } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                result.error("LEGACY", "Choose a folder to save the image", null)
            } else {
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name")?.replace(Regex("[/\\\\]"), "_")
                val album = call.argument<String>("album")?.replace(Regex("[^A-Za-z0-9 _-]"), "")?.take(60)?.ifBlank { "Eslam Money" } ?: "Eslam Money"
                if (bytes == null || bytes.isEmpty() || name.isNullOrBlank()) {
                    result.error("INVALID_IMAGE", "Image is empty", null)
                } else {
                    Thread {
                        var uri: android.net.Uri? = null
                        try {
                            val values = ContentValues().apply {
                                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/" + album)
                                put(MediaStore.Images.Media.IS_PENDING, 1)
                            }
                            uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                                ?: throw java.io.IOException("Cannot create image")
                            contentResolver.openOutputStream(uri!!)?.use { it.write(bytes) }
                                ?: throw java.io.IOException("Cannot write image")
                            contentResolver.update(uri!!, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
                            runOnUiThread { result.success(uri.toString()) }
                        } catch (e: Exception) {
                            uri?.let { contentResolver.delete(it, null, null) }
                            runOnUiThread { result.error("SAVE_FAILED", e.message, null) }
                        }
                    }.start()
                }
            }
        }
    }
}
