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
            } else {
                result.notImplemented()
            }
        }
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
}
