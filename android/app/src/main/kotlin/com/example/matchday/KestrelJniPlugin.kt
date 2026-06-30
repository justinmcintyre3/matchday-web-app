package com.example.matchday

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.nkhome.link.ballistics.nkmassdata.NkKestrel
import com.nkhome.link.ballistics.nkmassdata.k
import com.nkhome.link.ballistics.nkmassdata.BallisticsEnvironment
import android.content.Context
import android.provider.Settings







class KestrelJniPlugin(private val channel: MethodChannel, private val context: Context) : MethodCallHandler, k {
    private val kestrel: NkKestrel
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Polling thread for updateComs
    private var isPolling = false
    private val pollingRunnable = object : Runnable {
        override fun run() {
            if (isPolling) {
                kestrel.updateComs()
                flushTxBytes()
                mainHandler.postDelayed(this, 50)
            }
        }
    }

    init {
        kestrel = NkKestrel(this)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "connectJni" -> {
                kestrel.connectJni()
                isPolling = true
                mainHandler.post(pollingRunnable)
                result.success(null)
            }
            "getHostId" -> {
                val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown"
                val bytes = androidId.toByteArray()
                var i2 = 0
                for (i4 in bytes.indices) {
                    i2 += (((i2 % 9) * 5) + bytes[i4] + i2 + 5) * 212
                }
                for (i5 in bytes.indices) {
                    i2 += (((i2 % 2) * 18) + bytes[bytes.size - 1 - i5] + i2 + 6) * 1412
                }
                var i6 = i2 * 3
                if (i6 < 0) {
                    i6 = i2 * (-3)
                }
                val hostId = (i6 % 10000).toString()
                result.success(hostId)
            }
            "sendCmdStopEncrypting" -> {
                kestrel.sendCmdStopEncrypting()
                result.success(null)
            }
            "disconnectJni" -> {
                isPolling = false
                kestrel.disconnectJni()
                result.success(null)
            }
            "setRxBytes" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes != null) {
                    kestrel.setRxBytes(bytes)
                    kestrel.updateComs()
                    flushTxBytes()
                }
                result.success(null)
            }
            "sendCmdGetPrivacyStatus" -> {
                kestrel.sendCmdGetPrivacyStatus()
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendCmdPrivacyAuthenticate" -> {
                val hostPin = call.argument<String>("hostPin") ?: ""
                val periphPin = call.argument<String>("periphPin") ?: ""
                kestrel.sendCmdPrivacyAuthenticate(periphPin, hostPin)
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendCmdGetTgtInfoSettings" -> {
                kestrel.sendCmdGetTgtInfoSettings()
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendCmdGetGunTransferSettings" -> {
                kestrel.sendCmdGetGunTransferSettings()
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendCmdGetBalInfoSettings" -> {
                kestrel.sendCmdGetBalInfoSettings()
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendRequestAuth" -> {
                kestrel.sendRequestAuth()
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendSetEnvironment" -> {
                val latitude = call.argument<Double>("latitude")
                if (latitude != null) {
                    val env = BallisticsEnvironment()
                    env.initEnvironmentInvalid()
                    env.latitude = latitude.toFloat()
                    kestrel.sendSetEnvironment(env)
                    kestrel.updateComs()
                    flushTxBytes()
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun flushTxBytes() {
        while (kestrel.hasBytesToSend()) {
            val bytes = kestrel.getBytesToSend(20)
            if (bytes != null && bytes.isNotEmpty()) {
                mainHandler.post {
                    channel.invokeMethod("onTxBytes", bytes)
                }
            } else {
                break
            }
        }
    }

    private fun invokeFlutter(method: String, args: Any? = null) {
        mainHandler.post {
            channel.invokeMethod(method, args)
        }
    }

    // Implementing the 'k' interface methods
    override fun G(z4: Boolean) { invokeFlutter("rcvPrivacyStatus", z4) } // rcvPrivacyStatus
    override fun e(z4: Boolean) { invokeFlutter("rcvPrivacyAuthAck", z4) } // rcvPrivacyAuthAck
    override fun K(z4: Boolean) { invokeFlutter("updateAuthComplete", z4) } // updateAuthComplete
    override fun c(z4: Boolean) { invokeFlutter("rcvAuthRequestAck", z4) } // rcvAuthRequestAck

    // Stub the rest for now
    override fun A(z4: Boolean, i2: Int, i4: Int, i5: Int, iArr: IntArray?) { invokeFlutter("onGunTransferSettingsReceived", z4) }
    override fun B(str: String?) {}
    override fun E(str: String?) {}
    override fun F(z4: Boolean) {}
    override fun I(z4: Boolean) {}
    override fun J(i2: Int) {}
    override fun L(i2: Int) {}
    override fun M(f4: Float) {}
    override fun N(z4: Boolean) {}
    override fun O(z4: Boolean) {}
    override fun P(z4: Boolean) {}
    override fun Q(f4: Float, f5: Float, f6: Float, f7: Float, f8: Float, i2: Int, i4: Int, i5: Int, i6: Int, i7: Int) {}
    override fun S(z4: Boolean, pVar: Any?) {}
    override fun U(i2: Int, d4: Double, bVar: Any?) {}
    override fun W(f4: Float, f5: Float) {}
    override fun X(f4: Float, f5: Float, f6: Float, i2: Int, f7: Float, f8: Float, f9: Float, f10: Float, f11: Float, i4: Int) {}
    override fun Z(f4: Float, f5: Float, f6: Float, i2: Int) {}
    override fun c0(z4: Boolean) {}
    override fun d(z4: Boolean) {}
    override fun e0(f4: Float, f5: Float, f6: Float, f7: Float, f8: Float, f9: Float, i2: Int, i4: Int) {}
    override fun f(z4: Boolean) {}
    override fun g0(iVar: Any?) {}
    override fun i(z4: Boolean, qVar: Any?) {}
    override fun j0(i2: Int) {}
    override fun k(z4: Boolean, i2: Int, i4: Int, i5: Int, i6: Int) { invokeFlutter("onTgtInfoSettingsReceived", z4) }
    override fun k0(z4: Boolean) {}
    override fun m() {}
    override fun n0(z4: Boolean) {}
    override fun o(z4: Boolean) {}
    override fun o0(z4: Boolean) {}
    override fun p(i2: Int) {}
    override fun q(z4: Boolean) {}
    override fun t(i2: Int) {}
    override fun v(z4: Boolean) {}
    override fun x(z4: Boolean, cVar: Any?) { invokeFlutter("onBalInfoSettingsReceived", z4) }
    override fun z(eVar: Any?) {}
}
