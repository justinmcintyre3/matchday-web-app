package com.nkhome.link.ballistics.nkmassdata;

import android.util.Log;
import androidx.annotation.Keep;
@Keep
/* loaded from: classes.dex */
public class NkMassData {
    static {
        System.loadLibrary("NkMassData");
    }

    public NkMassData() {
        initMassData();
    }

    private native int addRxBytes(byte[] bArr, int i2);

    private native void cmdSendAbAck();

    private native void cmdSendAbHeartbeat();

    private native void cmdSendAbNack();

    private native void cmdSendAbStartGunDump();

    private native void cmdSendAuthRequest();

    private native void cmdSendCalcFullSolution(BallisticsDataInput ballisticsDataInput);

    private native void cmdSendEnableNkPEX();

    private native void cmdSendEnterBootloader(byte[] bArr, int i2);

    private native void cmdSendEraseGun(int i2);

    private native void cmdSendGetActiveGunIdx();

    private native void cmdSendGetBalInfoSettings();

    private native void cmdSendGetCurScreen();

    private native void cmdSendGetDeviceName();

    private native void cmdSendGetDeviceSN();

    private native void cmdSendGetEnvironment();

    private native void cmdSendGetGun(int i2);

    private native void cmdSendGetGunEnhanced(int i2, int i4, int i5);

    private native void cmdSendGetGunTransferSettings();

    private native void cmdSendGetPrivacyStatus();

    private native void cmdSendGetRemoteDisplayData(int i2);

    private native void cmdSendGetTgtInfoSettings();

    private native void cmdSendGetWezData();

    private native void cmdSendPrivacyAuthenticate(byte[] bArr, byte[] bArr2);

    private native void cmdSendSetActiveGunIdx(int i2);

    private native void cmdSendSetBalFullInputs(BallisticsDataInput ballisticsDataInput);

    private native void cmdSendSetBalInputs(BallisticsDataInput ballisticsDataInput);

    private native void cmdSendSetBalUnits(boolean z4);

    private native void cmdSendSetCurScreen(int i2);

    private native void cmdSendSetEnvironment(BallisticsEnvironment ballisticsEnvironment);

    private native void cmdSendSetGun(byte[] bArr, int i2, int i4, int i5);

    private native void cmdSendSetRemoteDisplayData(int i2, float f4, float f5, float f6, float f7, float f8);

    private native void cmdSendSetTgtInfoSettings(boolean z4);

    private native void cmdSendSetWezData(float f4, float f5, float f6, int i2);

    private native void cmdSendStartStopStreaming(int i2, int i4, int i5, int i6, int i7);

    private native void cmdSendStartStopSysStream(int i2, int i4);

    private native void cmdSendStopEncrypting();

    private native void cmdStartBleUpdate(byte[] bArr);

    private native byte[] getAbTempGun();

    private native byte[] getDeviceName();

    private native byte[] getDeviceSN();

    private native byte[] getReceivedSTBulletName();

    private native byte[] getReceivedSTProfileName();

    private native byte[] getRxGun();

    private native byte[] getTxBytes(int i2);

    private native boolean hasTxBytes();

    private native void initMassData();

    private native void resetMassData();

    private native void stopEncrypting();

    private native void updateMassData();

    public byte[] getAbProtoReceivedGun() {
        return getAbTempGun();
    }

    public byte[] getBytesToSend(int i2) {
        return getTxBytes(i2);
    }

    public byte[] getKestrelName() {
        return getDeviceName();
    }

    public byte[] getKestrelSN() {
        return getDeviceSN();
    }

    public byte[] getReceivedGun() {
        return getRxGun();
    }

    public byte[] getSTBulletName() {
        return getReceivedSTBulletName();
    }

    public byte[] getSTProfileName() {
        return getReceivedSTProfileName();
    }

    public boolean hasBytesToSend() {
        return hasTxBytes();
    }

    public void resetMd() {
        Log.d("NK-Kestrel", "NkMassData - resetMd()");
        resetMassData();
    }

    public void sendCalcFullSolution(BallisticsDataInput ballisticsDataInput) {
        cmdSendCalcFullSolution(ballisticsDataInput);
    }

    public void sendCmdAbAck() {
        cmdSendAbAck();
    }

    public void sendCmdAbHeartbeat() {
        cmdSendAbHeartbeat();
    }

    public void sendCmdAbNack() {
        cmdSendAbNack();
    }

    public void sendCmdAbStartGunDump() {
        cmdSendAbStartGunDump();
    }

    public void sendCmdEraseGun(int i2) {
        cmdSendEraseGun(i2);
    }

    public void sendCmdGetActiveGunIdx() {
        cmdSendGetActiveGunIdx();
    }

    public void sendCmdGetBalInfoSettings() {
        cmdSendGetBalInfoSettings();
    }

    public void sendCmdGetCurScreen() {
        cmdSendGetCurScreen();
    }

    public void sendCmdGetGun(int i2, int i4, int i5) {
        if (i5 == 0) {
            cmdSendGetGun(i2);
        } else {
            cmdSendGetGunEnhanced(i2, i4, i5);
        }
    }

    public void sendCmdGetGunTransferSettings() {
        cmdSendGetGunTransferSettings();
    }

    public void sendCmdGetPrivacyStatus() {
        cmdSendGetPrivacyStatus();
    }

    public void sendCmdGetTgtInfoSettings() {
        cmdSendGetTgtInfoSettings();
    }

    public void sendCmdPrivacyAuthenticate(String str, String str2) {
        if (!str2.isEmpty()) {
            Log.d("NK-Kestrel", "sendCmdPrivacyAuthenticate: periphPin: " + str + ", hostPin: " + str2);
            cmdSendPrivacyAuthenticate(str.getBytes(), str2.getBytes());
            return;
        }
        Log.d("NK-Kestrel", "sendCmdPrivacyAuthenticate: periphPin: " + str + ", hostPin: RESET PIN");
        cmdSendPrivacyAuthenticate(str.getBytes(), new byte[4]);
    }

    public void sendCmdSendEnterBootloader(byte[] bArr, int i2) {
        cmdSendEnterBootloader(bArr, i2);
    }

    public void sendCmdSetActiveGunIdx(int i2) {
        cmdSendSetActiveGunIdx(i2);
    }

    public void sendCmdSetBalFullInputs(BallisticsDataInput ballisticsDataInput) {
        cmdSendSetBalFullInputs(ballisticsDataInput);
    }

    public void sendCmdSetBalInputs(BallisticsDataInput ballisticsDataInput) {
        cmdSendSetBalInputs(ballisticsDataInput);
    }

    public void sendCmdSetBalUnits(boolean z4) {
        cmdSendSetBalUnits(z4);
    }

    public void sendCmdSetCurScreen(int i2) {
        cmdSendSetCurScreen(i2);
    }

    public void sendCmdSetGun(Object iVar, int i2) {
    }

    public void sendCmdSetTgtInfoSettings(boolean z4) {
        cmdSendSetTgtInfoSettings(z4);
    }

    public void sendCmdStartBleUpdate(byte[] bArr) {
        cmdStartBleUpdate(bArr);
    }

    public void sendCmdStopEncrypting() {
        cmdSendStopEncrypting();
    }

    public void sendEnableNkPEX() {
        cmdSendEnableNkPEX();
    }

    public void sendGetDeviceName() {
        cmdSendGetDeviceName();
    }

    public void sendGetDeviceSerialNum() {
        cmdSendGetDeviceSN();
    }

    public void sendGetEnvironment() {
        cmdSendGetEnvironment();
    }

    public void sendGetRemoteDisplayDataAb() {
        cmdSendGetRemoteDisplayData(0);
    }

    public void sendGetRemoteDisplayDataHornady() {
        cmdSendGetRemoteDisplayData(1);
    }

    public void sendGetWezData() {
        cmdSendGetWezData();
    }

    public void sendRequestAuth() {
        Log.d("NK-Kestrel", "NkMassData - sendRequestAuth() - Sending authentication request to Kestrel...");
        cmdSendAuthRequest();
    }

    public void sendSetAbSingleTargetData(Object dVar) {
    }

    public void sendSetEnvironment(BallisticsEnvironment ballisticsEnvironment) {
        cmdSendSetEnvironment(ballisticsEnvironment);
    }

    public void sendSetWezData(float f4, float f5, float f6, int i2) {
        cmdSendSetWezData(f4, f5, f6, i2);
    }

    public void sendStartStopStreamSysEvents(boolean z4) {
        cmdSendStartStopSysStream(z4 ? 1 : 0, 0);
    }

    public void sendStartStopStreaming(int i2, int i4, int i5, int i6, int i7) {
        cmdSendStartStopStreaming(i2, i4, i5, i6, i7);
    }

    public int setRxBytes(byte[] bArr) {
        return addRxBytes(bArr, bArr.length);
    }

    public void terminateEncryption() {
        stopEncrypting();
    }

    public void updateComs() {
        updateMassData();
    }
}
