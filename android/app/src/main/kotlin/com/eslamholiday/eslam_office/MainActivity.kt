package com.eslamholiday.eslam_office

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.os.Vibrator
import android.os.VibrationEffect
import io.flutter.FlutterInjector
import android.app.Activity
import android.content.Intent
import android.provider.ContactsContract
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var contactResult: MethodChannel.Result? = null
    private val contactRequest = 4201
    private var soundPool: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()
    private val loadedSounds = mutableSetOf<Int>()
    private val pendingSounds = mutableMapOf<Int, Float>()

    private fun feedback(event: String, style: String, sound: Boolean, haptic: Boolean, volume: Float, intensity: Float) {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // Sonification follows system sound volume, ringer mode and DND.
        if (sound && volume > 0 && audio.ringerMode == AudioManager.RINGER_MODE_NORMAL) {
            try {
                if (soundPool == null) {
                    soundPool = SoundPool.Builder().setMaxStreams(3).setAudioAttributes(
                        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()).build()
                    soundPool!!.setOnLoadCompleteListener { pool, id, status ->
                        if (status == 0) {
                            loadedSounds.add(id)
                            pendingSounds.remove(id)?.let { pool.play(id, it, it, 1, 0, 1f) }
                        } else pendingSounds.remove(id)
                    }
                }
                val path = "assets/sounds/${style}_${event}.wav"
                val id = soundIds.getOrPut(path) {
                    val asset = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(path)
                    val file = java.io.File(cacheDir, "eslam-${style}-${event}.wav")
                    if (!file.exists()) assets.open(asset).use { input -> file.outputStream().use { input.copyTo(it) } }
                    soundPool!!.load(file.path, 1)
                }
                if (loadedSounds.contains(id)) soundPool!!.play(id, volume, volume, 1, 0, 1f)
                else pendingSounds[id] = volume
            } catch (_: Exception) { /* A sound failure never blocks a form. */ }
        }
        if (haptic && intensity > 0) {
            try {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (vibrator.hasVibrator() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val amplitude = (intensity * 210 + 25).toInt().coerceIn(1, 255)
                    val timings = when (event) {
                        "save" -> longArrayOf(0, 16, 45, 20)
                        "error" -> longArrayOf(0, 24, 40, 24, 40, 24)
                        "alert" -> longArrayOf(0, 20, 45, 20)
                        "navigate" -> longArrayOf(0, 12)
                        else -> longArrayOf(0, 7)
                    }
                    val amplitudes = IntArray(timings.size) { if (it % 2 == 0) 0 else amplitude }
                    vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
                }
            } catch (_: Exception) { /* Honor devices without vibration. */ }
        }
    }
    override fun onPause() {
        pendingSounds.clear()
        soundPool?.autoPause()
        super.onPause()
    }
    override fun onDestroy() {
        soundPool?.release()
        soundPool = null
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != contactRequest) return
        val result = contactResult ?: return
        contactResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val columns = arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER)
            contentResolver.query(uri, columns, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    result.success(mapOf("name" to cursor.getString(0), "phone" to cursor.getString(1)))
                } else result.success(null)
            } ?: result.success(null)
        } catch (e: Exception) {
            result.error("CONTACT_READ_FAILED", "Cannot read selected contact", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eslam_money/experience").setMethodCallHandler { call, result ->
            if (call.method != "feedback") result.notImplemented()
            else {
                val event = call.argument<String>("event") ?: "select"
                val style = call.argument<String>("style") ?: "soft"
                if (event !in listOf("select", "navigate", "save", "alert", "error") || style !in listOf("soft", "pop", "bell")) {
                    result.error("INVALID_FEEDBACK", "Unknown feedback", null)
                } else {
                    feedback(event, style, call.argument<Boolean>("sound") == true, call.argument<Boolean>("haptic") == true,
                        (call.argument<Double>("volume") ?: 0.25).toFloat().coerceIn(0f, 1f),
                        (call.argument<Double>("intensity") ?: 0.45).toFloat().coerceIn(0f, 1f))
                    result.success(null)
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eslam_money/contacts").setMethodCallHandler { call, result ->
            if (call.method != "pickPhone") {
                result.notImplemented()
            } else if (contactResult != null) {
                result.error("BUSY", "Contact picker already open", null)
            } else {
                contactResult = result
                try {
                    val intent = Intent(Intent.ACTION_PICK).apply { type = ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE }
                    startActivityForResult(intent, contactRequest)
                } catch (e: Exception) {
                    contactResult = null
                    result.error("CONTACT_PICK_FAILED", "Cannot open contacts", null)
                }
            }
        }
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
