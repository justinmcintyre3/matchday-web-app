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
            "sendCmdSetActiveGunIdx" -> {
                val index = call.argument<Int>("index") ?: 0
                kestrel.sendCmdSetActiveGunIdx(index)
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendCmdGetGun" -> {
                val index = call.argument<Int>("index") ?: 0
                val format = call.argument<Int>("format") ?: 0
                val version = call.argument<Int>("version") ?: 0
                kestrel.sendCmdGetGun(index, format, version)
                kestrel.updateComs()
                flushTxBytes()
                result.success(null)
            }
            "sendCmdGetRemoteDisplayData" -> {
                val gunFormat = call.argument<Int>("gunFormat") ?: 0
                if (gunFormat == 2) {
                    kestrel.sendGetRemoteDisplayDataHornady()
                } else {
                    kestrel.sendGetRemoteDisplayDataAb()
                }
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

    private fun extractProfileNameFromRemoteDisplay(profileObj: Any?): String {
        var name = ""
        if (profileObj != null) {
            try {
                val lMethod = profileObj.javaClass.getMethod("l")
                name = lMethod.invoke(profileObj) as? String ?: ""
            } catch (e: Exception) {
                try {
                    val field = profileObj.javaClass.getField("profileName")
                    name = field.get(profileObj) as? String ?: ""
                } catch (e2: Exception) {}
            }
        }
        if (name.isEmpty()) {
            name = extractProfileNameFromStBytes()
        }
        return name.trim()
    }

    private fun extractProfileNameFromStBytes(): String {
        return try {
            val stProfileBytes = kestrel.getSTProfileName()
            if (stProfileBytes != null && stProfileBytes.isNotEmpty()) {
                val s = String(stProfileBytes).trim()
                if (s.isNotEmpty() && s != "---" && s.all { it >= ' ' && it <= '~' }) {
                    s
                } else {
                    ""
                }
            } else {
                ""
            }
        } catch (e: Exception) {
            ""
        }
    }

    private fun emitActiveGunProfile(name: String, index: Int = 0) {
        val trimmed = name.trim()
        if (trimmed.isEmpty() || trimmed == "---") return
        mainHandler.post {
            channel.invokeMethod("onActiveGunProfileReceived", mapOf(
                "index" to index,
                "name" to trimmed,
            ))
        }
    }

    private fun solutionMap(
        elevation: Float,
        windage1: Float,
        windage2: Float,
        lead: Float,
        targetNumber: Int,
        solutionId: Int = targetNumber,
        velocity: Float = 0f,
        energy: Float = 0f,
        tof: Float = 0f,
        spinD: Float = 0f,
        targetRange: Float = 0f,
    ): Map<String, Any> {
        return mapOf(
            "elevation" to elevation,
            "windage1" to windage1,
            "windage2" to windage2,
            "lead" to lead,
            "targetNumber" to targetNumber,
            "solutionId" to solutionId,
            "velocity" to velocity,
            "energy" to energy,
            "tof" to tof,
            "spinD" to spinD,
            "targetRange" to targetRange,
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
        mainHandler.post {
            channel.invokeMethod("onGunTransferSettingsReceived", mapOf(
                "success" to z4,
                "activeGunIdx" to i2,
                "gunFormat" to i4,
                "gunVersion" to i5
            ))
        }
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

    override fun S(z4: Boolean, pVar: Any?) {
        val name = extractProfileNameFromRemoteDisplay(pVar)
        android.util.Log.d("NK-JNI", "S callback: extracted name='$name'")
        if (z4) {
            emitActiveGunProfile(name)
        }
    }
    override fun U(i2: Int, d4: Double, bVar: Any?) {
        var name = ""
        val rx = kestrel.receivedGun
        val rxAb = kestrel.getAbProtoReceivedGun()
        val stProfileBytes = kestrel.getSTProfileName()

        if (bVar != null) {
            try {
                val field = bVar.javaClass.getField("pro")
                name = field.get(bVar) as? String ?: ""
            } catch (e: Exception) {
                try {
                    val kMethod = bVar.javaClass.getMethod("k")
                    val json = kMethod.invoke(bVar) as? String ?: ""
                    val matcher = java.util.regex.Pattern.compile("\"pro\"\\s*:\\s*\"([^\"]+)\"").matcher(json)
                    if (matcher.find()) {
                        name = matcher.group(1) ?: ""
                    }
                } catch (e2: Exception) {
                    try {
                        for (f in bVar.javaClass.fields) {
                            if (f.type == String::class.java) {
                                val s = f.get(bVar) as? String
                                if (s != null && s.isNotEmpty() && s.length <= 12 && !s.contains("{") && !s.contains("}")) {
                                    name = s
                                    break
                                }
                            }
                        }
                    } catch (e3: Exception) {}
                }
            }
        }
        if (name.isEmpty()) {
            try {
                if (rx != null && rx.size >= 14) {
                    val bArr = ByteArray(12)
                    System.arraycopy(rx, 2, bArr, 0, 12)
                    val s = String(bArr).trim()
                    if (s.isNotEmpty() && s.all { it >= ' ' && it <= '~' }) {
                        name = s
                    }
                }
            } catch (e: Exception) {}
        }
        if (name.isEmpty()) {
            try {
                if (rxAb != null && rxAb.size >= 14) {
                    val bArr = ByteArray(12)
                    System.arraycopy(rxAb, 2, bArr, 0, 12)
                    val s = String(bArr).trim()
                    if (s.isNotEmpty() && s.all { it >= ' ' && it <= '~' }) {
                        name = s
                    }
                }
            } catch (e: Exception) {}
        }
        if (name.isEmpty()) {
            try {
                if (stProfileBytes != null && stProfileBytes.isNotEmpty()) {
                    val s = String(stProfileBytes).trim()
                    if (s.isNotEmpty() && s != "---" && s.all { it >= ' ' && it <= '~' }) {
                        name = s
                    }
                }
            } catch (e: Exception) {}
        }
        android.util.Log.d("NK-JNI", "U callback: extracted name='$name' for index=$i2")
        mainHandler.post {
            channel.invokeMethod("onActiveGunProfileReceived", mapOf(
                "index" to i2,
                "name" to name.trim()
            ))
        }
    }
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
            solutionMap(f4, f5, f6, 0f, i2, i4),
        )
    }

    override fun f(z4: Boolean) {}
    override fun g0(iVar: Any?) {
        var name = ""
        val rx = kestrel.receivedGun
        val rxAb = kestrel.getAbProtoReceivedGun()
        val stProfileBytes = kestrel.getSTProfileName()

        android.util.Log.d("NK-JNI", "g0 callback: iVar=$iVar, iVarClass=${iVar?.javaClass?.name}")
        if (iVar != null) {
            try {
                val kMethod = iVar.javaClass.getMethod("k")
                val json = kMethod.invoke(iVar) as? String ?: ""
                android.util.Log.d("NK-JNI", "iVar k() output: $json")
            } catch (e: Exception) {
                android.util.Log.e("NK-JNI", "Error calling k()", e)
            }

            // Inspect all fields
            try {
                for (f in iVar.javaClass.fields) {
                    f.isAccessible = true
                    val valStr = try { f.get(iVar)?.toString() ?: "null" } catch(e: Exception) { "error" }
                    android.util.Log.d("NK-JNI", "Field: ${f.name} (type ${f.type.name}) = $valStr")
                }
            } catch (e: Exception) {
                android.util.Log.e("NK-JNI", "Error inspecting fields", e)
            }

            try {
                val field = iVar.javaClass.getField("pro")
                name = field.get(iVar) as? String ?: ""
                android.util.Log.d("NK-JNI", "Successfully got field pro: '$name'")
            } catch (e: Exception) {
                android.util.Log.e("NK-JNI", "Error getting field 'pro' directly", e)
            }
        }

        android.util.Log.d("NK-JNI", "g0 callback: rx size=${rx?.size}, rxAb size=${rxAb?.size}, stProfileBytes size=${stProfileBytes?.size}")
        if (rx != null) {
            android.util.Log.d("NK-JNI", "rx hex: " + rx.joinToString("") { String.format("%02x", it) })
        }
        if (rxAb != null) {
            android.util.Log.d("NK-JNI", "rxAb hex: " + rxAb.joinToString("") { String.format("%02x", it) })
        }
        if (stProfileBytes != null) {
            android.util.Log.d("NK-JNI", "stProfileBytes hex: " + stProfileBytes.joinToString("") { String.format("%02x", it) })
            android.util.Log.d("NK-JNI", "stProfileBytes string: " + String(stProfileBytes).trim())
        }

        if (name.isEmpty()) {
            try {
                if (rx != null && rx.size >= 14) {
                    val bArr = ByteArray(12)
                    System.arraycopy(rx, 2, bArr, 0, 12)
                    val s = String(bArr).trim()
                    if (s.isNotEmpty() && s.all { it >= ' ' && it <= '~' }) {
                        name = s
                    }
                }
            } catch (e: Exception) {}
        }
        if (name.isEmpty()) {
            try {
                if (rxAb != null && rxAb.size >= 14) {
                    val bArr = ByteArray(12)
                    System.arraycopy(rxAb, 2, bArr, 0, 12)
                    val s = String(bArr).trim()
                    if (s.isNotEmpty() && s.all { it >= ' ' && it <= '~' }) {
                        name = s
                    }
                }
            } catch (e: Exception) {}
        }
        if (name.isEmpty()) {
            try {
                if (stProfileBytes != null && stProfileBytes.isNotEmpty()) {
                    val s = String(stProfileBytes).trim()
                    if (s.isNotEmpty() && s != "---" && s.all { it >= ' ' && it <= '~' }) {
                        name = s
                    }
                }
            } catch (e: Exception) {}
        }
        android.util.Log.d("NK-JNI", "g0 callback: final extracted name='$name'")
        if (name.isNotEmpty()) {
            mainHandler.post {
                channel.invokeMethod("onActiveGunProfileReceived", mapOf(
                    "index" to 0,
                    "name" to name.trim()
                ))
            }
        }
    }
    override fun i(z4: Boolean, qVar: Any?) {
        val name = extractProfileNameFromRemoteDisplay(qVar)
        android.util.Log.d("NK-JNI", "i callback (Hornady): extracted name='$name'")
        if (z4) {
            emitActiveGunProfile(name)
        }
    }
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
                eVar.Lead,
                eVar.TargetNumber,
                eVar.SolutionId,
                eVar.Velocity,
                eVar.Energy,
                eVar.ToF,
                eVar.SpinD,
                eVar.TargetRange,
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
