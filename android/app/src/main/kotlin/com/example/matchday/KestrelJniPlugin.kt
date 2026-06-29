package com.example.matchday

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.nkhome.link.ballistics.nkmassdata.NkKestrel
import com.nkhome.link.ballistics.nkmassdata.k







class KestrelJniPlugin(private val channel: MethodChannel) : MethodCallHandler, k {
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
            "sendRequestAuth" -> {
                kestrel.sendRequestAuth()
                kestrel.updateComs()
                flushTxBytes()
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
    override fun A(z4: Boolean, i2: Int, i4: Int, i5: Int, iArr: IntArray?) {}
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
    override fun k(z4: Boolean, i2: Int, i4: Int, i5: Int, i6: Int) {}
    override fun k0(z4: Boolean) {}
    override fun m() {}
    override fun n0(z4: Boolean) {}
    override fun o(z4: Boolean) {}
    override fun o0(z4: Boolean) {}
    override fun p(i2: Int) {}
    override fun q(z4: Boolean) {}
    override fun t(i2: Int) {}
    override fun v(z4: Boolean) {}
    override fun x(z4: Boolean, cVar: Any?) {}
    override fun z(eVar: Any?) {}
}
