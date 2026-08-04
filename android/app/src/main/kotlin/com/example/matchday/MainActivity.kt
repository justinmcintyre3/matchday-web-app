package com.example.matchday

import android.content.Intent
import androidx.wear.remote.interactions.RemoteActivityHelper
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.matchday/kestrel_jni"
    private val WEAR_CHANNEL = "com.matchday/wear_os"

    private var tts: android.speech.tts.TextToSpeech? = null
    private var isTtsInitialized = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        initTTS()
    }

    private fun initTTS() {
        try {
            tts = android.speech.tts.TextToSpeech(this) { status ->
                if (status == android.speech.tts.TextToSpeech.SUCCESS) {
                    isTtsInitialized = true
                    tts?.language = java.util.Locale.US
                    tts?.setSpeechRate(1.0f)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        // KestrelJniPlugin sets itself as the call handler inside its init block
        KestrelJniPlugin(channel, context)

        val wearChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEAR_CHANNEL)
        wearChannel.setMethodCallHandler { call, result ->
            if (call.method == "launchWatchApp") {
                launchWatchApp()
                result.success(null)
            } else if (call.method == "playTone") {
                val freq = call.argument<Double>("frequency") ?: 1500.0
                val duration = call.argument<Int>("durationMs") ?: 250
                val count = call.argument<Int>("count") ?: 1
                val silenceMs = call.argument<Int>("silenceMs") ?: 250
                playTone(freq, duration, count, silenceMs)
                result.success(null)
            } else if (call.method == "playNativeSound") {
                val fileName = call.argument<String>("fileName") ?: ""
                if (fileName.isNotEmpty()) {
                    playNativeSound(fileName)
                }
                result.success(null)
            } else if (call.method == "speakText") {
                val text = call.argument<String>("text") ?: ""
                if (text.isNotEmpty()) {
                    speakText(text)
                }
                result.success(null)
            } else if (call.method == "stopSpeaking") {
                stopSpeaking()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun speakText(text: String) {
        val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
        if (audioManager.ringerMode == android.media.AudioManager.RINGER_MODE_NORMAL) {
            try {
                if (isTtsInitialized && tts != null) {
                    val phoneticText = text.replace(Regex("(?i)\\blead\\b"), "leed")
                    val params = android.os.Bundle()
                    params.putInt(android.speech.tts.TextToSpeech.Engine.KEY_PARAM_STREAM, android.media.AudioManager.STREAM_MUSIC)
                    tts?.speak(phoneticText, android.speech.tts.TextToSpeech.QUEUE_FLUSH, params, "matchday_phone_tts_id")
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun stopSpeaking() {
        try {
            if (isTtsInitialized && tts != null) {
                tts?.stop()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun playNativeSound(fileName: String) {
        try {
            val assetDescriptor = assets.openFd("flutter_assets/assets/audio/$fileName")
            val mediaPlayer = android.media.MediaPlayer()
            val audioAttributes = android.media.AudioAttributes.Builder()
                .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            mediaPlayer.setAudioAttributes(audioAttributes)
            mediaPlayer.setDataSource(
                assetDescriptor.fileDescriptor,
                assetDescriptor.startOffset,
                assetDescriptor.length
            )
            assetDescriptor.close()
            mediaPlayer.prepare()
            mediaPlayer.start()
            mediaPlayer.setOnCompletionListener { mp -> mp.release() }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun playTone(frequency: Double, durationMs: Int, count: Int = 1, silenceMs: Int = 250) {
        Thread {
            try {
                val sampleRate = 44100
                val beepSamples = (sampleRate * (durationMs / 1000.0)).toInt()
                val silenceSamples = (sampleRate * (silenceMs / 1000.0)).toInt()
                val cycleLength = beepSamples + silenceSamples
                val totalSamples = count * beepSamples + (count - 1) * silenceSamples

                val buffer = ShortArray(totalSamples)
                val twoPi = 2.0 * Math.PI
                var phase = 0.0
                val fadeSamples = 441 // 10ms linear fade

                for (s in 0 until totalSamples) {
                    val localS = s % cycleLength
                    if (localS < beepSamples) {
                        val rawSample = 12000 * Math.sin(phase)
                        val factor = when {
                            localS < fadeSamples -> localS.toDouble() / fadeSamples
                            localS > beepSamples - fadeSamples -> (beepSamples - localS).toDouble() / fadeSamples
                            else -> 1.0
                        }
                        buffer[s] = (rawSample * factor).toInt().toShort()

                        phase += twoPi * frequency / sampleRate
                        if (phase > twoPi) phase -= twoPi
                    } else {
                        buffer[s] = 0
                        phase = 0.0
                    }
                }

                val audioAttributes = android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
                val audioFormat = android.media.AudioFormat.Builder()
                    .setChannelMask(android.media.AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(android.media.AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .build()
                val track = android.media.AudioTrack(
                    audioAttributes,
                    audioFormat,
                    buffer.size * 2,
                    android.media.AudioTrack.MODE_STATIC,
                    android.media.AudioManager.AUDIO_SESSION_ID_GENERATE
                )
                track.write(buffer, 0, buffer.size)
                track.play()
                val patternDurationMs = count * durationMs + (count - 1) * silenceMs
                Thread.sleep(patternDurationMs.toLong() + 100)
                track.stop()
                track.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun launchWatchApp() {
        val remoteActivityHelper = RemoteActivityHelper(context)
        val nodeClient = Wearable.getNodeClient(context)
        nodeClient.connectedNodes.addOnSuccessListener { nodes ->
            for (node in nodes) {
                val intent = Intent(Intent.ACTION_VIEW)
                    .addCategory(Intent.CATEGORY_BROWSABLE)
                    .setData(android.net.Uri.parse("matchday://launch"))
                remoteActivityHelper.startRemoteActivity(intent, node.id)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            tts?.shutdown()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
