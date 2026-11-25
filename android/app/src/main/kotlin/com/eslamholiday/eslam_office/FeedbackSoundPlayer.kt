package com.eslamholiday.eslam_office

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import java.io.File

/** Short app effects use media volume, independently of ringtone/system volume. */
class FeedbackSoundPlayer(private val context: Context) {
    val attributes: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private var pool: SoundPool? = null
    private var foreground = true
    private val ids = mutableMapOf<String, Int>()
    private val loaded = mutableSetOf<Int>()
    private data class Request(val volume: Float, val done: (String, Int) -> Unit)
    private val pending = mutableMapOf<Int, MutableList<Request>>()

    fun play(event: String, style: String, volume: Float, done: (String, Int) -> Unit) {
        val request = Request(volume.coerceIn(0f, 1f), done)
        blocked(request)?.let { done(it, 0); return }
        try {
            val player = pool ?: SoundPool.Builder().setMaxStreams(3)
                .setAudioAttributes(attributes).build().also { created ->
                    pool = created
                    created.setOnLoadCompleteListener { owner, id, status ->
                        if (owner !== pool) return@setOnLoadCompleteListener
                        val waiting = pending.remove(id).orEmpty()
                        if (status == 0) {
                            loaded.add(id)
                            // Coalesce taps while decoding; every caller still gets a result.
                            waiting.lastOrNull()?.let { latest ->
                                start(owner, id, latest) { state, stream ->
                                    waiting.forEach { it.done(state, stream) }
                                }
                            }
                        } else {
                            ids.entries.removeAll { it.value == id }
                            Log.w("EslamFeedback", "Sound decoding failed: $status")
                            waiting.forEach { it.done("error", 0) }
                        }
                    }
                }
            val path = "assets/sounds/${style}_${event}.wav"
            val id = ids[path] ?: run {
                val asset = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(path)
                val file = File(context.cacheDir, "eslam-${style}-${event}.wav")
                // Refresh cached bytes on first use after an app update.
                context.assets.open(asset).use { input -> file.outputStream().use { input.copyTo(it) } }
                player.load(file.path, 1).also { sample ->
                    check(sample != 0) { "Sound load was rejected" }
                    ids[path] = sample
                }
            }
            if (id in loaded) start(player, id, request, done)
            else {
                val waiting = pending.getOrPut(id) { mutableListOf() }
                waiting.add(request)
                handler.postDelayed({
                    if (pending[id] === waiting) {
                        pending.remove(id)
                        waiting.forEach { it.done("error", 0) }
                    }
                }, 5000)
            }
        } catch (error: Exception) {
            Log.w("EslamFeedback", "Cannot load app sound", error)
            done("error", 0)
        }
    }

    private fun blocked(request: Request): String? = when {
        !foreground -> "background"
        request.volume <= 0f -> "app_muted"
        audio.getStreamVolume(AudioManager.STREAM_MUSIC) == 0 -> "device_muted"
        else -> null
    }

    private fun start(player: SoundPool, id: Int, request: Request, done: (String, Int) -> Unit) {
        blocked(request)?.let { done(it, 0); return }
        val stream = player.play(id, request.volume, request.volume, 1, 0, 1f)
        done(if (stream > 0) "played" else "error", stream)
    }

    fun resume() { foreground = true }
    fun pause() {
        foreground = false
        val waiting = pending.values.flatten()
        pending.clear()
        waiting.forEach { it.done("background", 0) }
        pool?.autoPause()
    }
    fun release() {
        pause()
        pool?.release()
        pool = null
        ids.clear()
        loaded.clear()
    }
}
