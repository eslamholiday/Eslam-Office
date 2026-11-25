package com.eslamholiday.eslam_office

import android.app.Activity
import android.app.Instrumentation
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Exercises Android decoding/playback, rather than only tapping Flutter controls. */
class FeedbackSoundInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }

    override fun onStart() {
        val summary = Bundle()
        val audio = targetContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val originalMode = audio.ringerMode
        val originalMedia = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
        val originalSystem = audio.getStreamVolume(AudioManager.STREAM_SYSTEM)
        var player: FeedbackSoundPlayer? = null
        var activity: MainActivity? = null
        var success = false
        try {
            activity = startActivitySync(Intent(targetContext, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as MainActivity
            waitForIdleSync()
            runOnMainSync { player = FeedbackSoundPlayer(targetContext) }
            val sounds = checkNotNull(player)
            check(checkNotNull(activity).volumeControlStream == AudioManager.STREAM_MUSIC)
            check(sounds.attributes.volumeControlStream == AudioManager.STREAM_MUSIC)

            fun play(style: String = "silk", event: String = "navigate", volume: Float = .6f): Pair<String, Int> {
                val latch = CountDownLatch(1)
                var outcome: Pair<String, Int>? = null
                runOnMainSync {
                    sounds.play(event, style, volume) { state, stream ->
                        outcome = state to stream
                        latch.countDown()
                    }
                }
                check(latch.await(8, TimeUnit.SECONDS)) { "Audio callback timed out" }
                return checkNotNull(outcome)
            }

            var count = 0
            fun waitUntil(message: String, condition: () -> Boolean) {
                repeat(50) {
                    if (condition()) return
                    Thread.sleep(50)
                }
                check(condition()) { message }
            }
            for (mode in listOf(AudioManager.RINGER_MODE_NORMAL, AudioManager.RINGER_MODE_VIBRATE, AudioManager.RINGER_MODE_SILENT)) {
                // SYSTEM is aliased to RING on phones; zeroing it can change ringer mode.
                // Set the requested mode afterwards, and wait for AudioService to apply it.
                audio.setStreamVolume(AudioManager.STREAM_SYSTEM, 0, 0)
                audio.ringerMode = mode
                waitUntil("Could not set ringer mode $mode") { audio.ringerMode == mode }
                audio.setStreamVolume(AudioManager.STREAM_MUSIC, audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC), 0)
                waitUntil("Media remained muted") { audio.getStreamVolume(AudioManager.STREAM_MUSIC) > 0 }
                if (mode != AudioManager.RINGER_MODE_NORMAL) {
                    check(audio.getStreamVolume(AudioManager.STREAM_SYSTEM) == 0)
                }
                // New decode and cached replay must both reach an Android audio stream.
                val style = listOf("silk", "wood", "crystal")[mode]
                repeat(2) {
                    val (state, stream) = play(style)
                    check(state == "played" && stream > 0) { "No playback in ringer mode $mode: $state/$stream" }
                    count++
                    Thread.sleep(180)
                }
            }
            for (style in listOf("soft", "pop", "bell", "silk", "wood", "crystal", "water")) {
                for (event in listOf("select", "navigate", "save", "alert", "error")) {
                    val (state, stream) = play(style, event)
                    check(state == "played" && stream > 0) { "$style/$event did not decode and play: $state" }
                    count++
                    Thread.sleep(180)
                }
            }
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
            waitUntil("Media did not mute") { audio.getStreamVolume(AudioManager.STREAM_MUSIC) == 0 }
            check(play().first == "device_muted")
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC), 0)
            waitUntil("Media did not unmute") { audio.getStreamVolume(AudioManager.STREAM_MUSIC) > 0 }
            check(play(volume = 0f).first == "app_muted")
            check(play(style = "missing_asset").first == "error")
            runOnMainSync { sounds.pause() }
            check(play().first == "background")
            runOnMainSync { sounds.resume() }
            check(play().first == "played")
            runOnMainSync { sounds.release(); sounds.resume() }
            check(play().first == "played")
            summary.putString("stream", "OK: $count decoded/playback checks; normal/vibrate/silent; system volume zero; mute/error/lifecycle checks passed")
            success = true
        } catch (error: Throwable) {
            summary.putString("stream", error.stackTraceToString())
        } finally {
            runOnMainSync { player?.release(); activity?.finish() }
            audio.ringerMode = originalMode
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, originalMedia, 0)
            audio.setStreamVolume(AudioManager.STREAM_SYSTEM, originalSystem, 0)
        }
        finish(if (success) Activity.RESULT_OK else Activity.RESULT_CANCELED, summary)
    }
}
