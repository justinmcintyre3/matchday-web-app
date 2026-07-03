package com.example.matchday

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.nkhome.link.ballistics.nkmassdata.BallisticsDataInput
import com.nkhome.link.ballistics.nkmassdata.BallisticsEnvironment
import com.nkhome.link.ballistics.nkmassdata.NkKestrel
import com.nkhome.link.ballistics.nkmassdata.e
import com.nkhome.link.ballistics.nkmassdata.k
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class KestrelJniPlugin(private val channel: MethodChannel, private val context: Context) :
    MethodCallHandler, k {
    private val kestrel: NkKestrel
    private val mainHandler = Handler(Looper.getMainLooper())

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
                val androidId =
                    Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                        ?: "unknown"
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
                result.success((i6 % 10000).toString())
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
            "sendCmdGetEnvironment" -> {
                kestrel.sendGetEnvironment()
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendCmdGetDeviceName" -> {
                kestrel.sendGetDeviceName()
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendCmdGetDeviceSerialNum" -> {
                kestrel.sendGetDeviceSerialNum()
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendCmdSetBalFullInputs" -> {
                val input = buildBalFullInputs(call)
                if (input == null) {
                    result.error("INVALID_INPUT", "Target inputs failed validation", null)
                    return
                }
                kestrel.sendCmdSetBalFullInputs(input)
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendCalcFullSolution" -> {
                val targetNumber = call.argument<Int>("targetNumber") ?: 0
                val input = BallisticsDataInput()
                input.targetNumber = targetNumber.toByte()
                input.solutionId = targetNumber.toByte()
                input.doExtraCalcs = (-1).toByte()
                input.setAsActiveTgt = 0
                kestrel.sendCalcFullSolution(input)
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun buildBalFullInputs(call: MethodCall): BallisticsDataInput? {
        val targetNumber = call.argument<Int>("targetNumber") ?: return null
        val rangeYards = call.argument<Double>("targetRangeYards") ?: return null
        val directionOfFire = call.argument<Double>("directionOfFire")?.toFloat() ?: 0f
        val windSpeed1Mph = call.argument<Double>("windSpeed1Mph")?.toFloat() ?: 0f
        val windSpeed2Mph = call.argument<Double>("windSpeed2Mph")?.toFloat() ?: 0f
        val windDirection = call.argument<Double>("windDirection")?.toFloat() ?: 0f
        val inclinationAngle = call.argument<Double>("inclinationAngle")?.toFloat() ?: 0f
        val targetSpeedMph = call.argument<Double>("targetSpeedMph")?.toFloat() ?: 0f

        val input = BallisticsDataInput()
        input.setTargetRange((rangeYards * YARDS_TO_METERS).toFloat())
        input.setDirectionOfFire(normalizeDegrees(directionOfFire))
        input.setWindSpeed1(windSpeed1Mph * MPH_TO_MS)
        input.setWindSpeed2(windSpeed2Mph * MPH_TO_MS)
        input.setWindDirection(normalizeDegrees(windDirection))
        input.setInclinationAngle(inclinationAngle)
        input.setTargetSpeed(targetSpeedMph * MPH_TO_MS)
        input.setTargetNumber(targetNumber.toByte())
        input.setSolutionId(targetNumber.toByte())
        input.useCurrentTarget = 0
        input.applyDefaultValidation()
        input.latitudeIsValid = 0

        return if (input.isDataValid()) input else null
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

    private fun solutionMap(
        elevation: Float,
        windage1: Float,
        windage2: Float,
        targetNumber: Int,
        solutionId: Int = targetNumber,
    ): Map<String, Any> {
        return mapOf(
            "elevation" to elevation,
            "windage1" to windage1,
            "windage2" to windage2,
            "targetNumber" to targetNumber,
            "solutionId" to solutionId,
        )
    }

    override fun G(z4: Boolean) {
        invokeFlutter("rcvPrivacyStatus", z4)
    }

    override fun e(z4: Boolean) {
        invokeFlutter("rcvPrivacyAuthAck", z4)
    }

    override fun K(z4: Boolean) {
        invokeFlutter("updateAuthComplete", z4)
    }

    override fun c(z4: Boolean) {
        invokeFlutter("rcvAuthRequestAck", z4)
    }

    override fun A(z4: Boolean, i2: Int, i4: Int, i5: Int, iArr: IntArray?) {
        invokeFlutter("onGunTransferSettingsReceived", z4)
    }

    override fun B(str: String?) {
        invokeFlutter("onDeviceSNReceived", str)
    }
    override fun E(str: String?) {
        invokeFlutter("onDeviceNameReceived", str)
    }
    override fun F(z4: Boolean) {}
    override fun I(z4: Boolean) {
        invokeFlutter("onSetRemoteSolnAck", z4)
    }

    override fun J(i2: Int) {}
    override fun L(i2: Int) {}
    override fun M(f4: Float) {}
    override fun N(z4: Boolean) {}
    override fun O(z4: Boolean) {}
    override fun P(z4: Boolean) {}
    override fun Q(
        f4: Float,
        f5: Float,
        f6: Float,
        f7: Float,
        f8: Float,
        i2: Int,
        i4: Int,
        i5: Int,
        i6: Int,
        i7: Int,
    ) {
        invokeFlutter("onEnvironmentReceived", mapOf(
            "latitude" to f4,
            "dryBulbTemp" to f5,
            "stationPress" to f6,
            "relativeHum" to f7,
            "densityAltitude" to f8
        ))
    }

    override fun S(z4: Boolean, pVar: Any?) {}
    override fun U(i2: Int, d4: Double, bVar: Any?) {}
    override fun W(f4: Float, f5: Float) {}

    override fun X(
        f4: Float,
        f5: Float,
        f6: Float,
        i2: Int,
        f7: Float,
        f8: Float,
        f9: Float,
        f10: Float,
        f11: Float,
        i4: Int,
    ) {}

    override fun Z(f4: Float, f5: Float, f6: Float, i2: Int) {}
    override fun c0(z4: Boolean) {}
    override fun d(z4: Boolean) {}

    override fun e0(
        f4: Float,
        f5: Float,
        f6: Float,
        f7: Float,
        f8: Float,
        f9: Float,
        i2: Int,
        i4: Int,
    ) {
        invokeFlutter(
            "onBalFullSolution",
            solutionMap(f4, f5, f6, i2, i4),
        )
    }

    override fun f(z4: Boolean) {}
    override fun g0(iVar: Any?) {}
    override fun i(z4: Boolean, qVar: Any?) {}
    override fun j0(i2: Int) {}

    override fun k(z4: Boolean, i2: Int, i4: Int, i5: Int, i6: Int) {
        invokeFlutter("onTgtInfoSettingsReceived", z4)
    }

    override fun k0(z4: Boolean) {}
    override fun m() {}
    override fun n0(z4: Boolean) {}
    override fun o(z4: Boolean) {}
    override fun o0(z4: Boolean) {}
    override fun p(i2: Int) {}

    override fun q(z4: Boolean) {
        invokeFlutter("onCalcFullSolnAck", z4)
    }

    override fun t(i2: Int) {}
    override fun v(z4: Boolean) {}

    override fun x(z4: Boolean, cVar: Any?) {
        invokeFlutter("onBalInfoSettingsReceived", z4)
    }

    override fun z(eVar: Any?) {
        if (eVar !is e) return
        invokeFlutter(
            "onBalFullSolution",
            solutionMap(
                eVar.Elevation,
                eVar.Wnd1,
                eVar.Wnd2,
                eVar.TargetNumber,
                eVar.SolutionId,
            ),
        )
    }

    companion object {
        private const val YARDS_TO_METERS = 0.9144
        private const val MPH_TO_MS = 0.44704f

        private fun normalizeDegrees(value: Float): Float {
            var normalized = value % 360f
            if (normalized < 0f) normalized += 360f
            return if (normalized >= 360f) 0f else normalized
        }
    }
}
