package com.nkhome.link.ballistics.nkmassdata;

import androidx.annotation.Keep;
@Keep
/* loaded from: classes.dex */
public class BallisticsEnvironment {
    public byte aeroJumpEnable;
    public byte autoUpdateEnable;
    public byte coriolisEnable;
    public float densityAltitude;
    public float dryBulbTemp;
    public float latitude;
    public float relativeHum;
    public byte spinDriftEnable;
    public float stationPress;
    public byte windCaptureAll;

    public void initEnvironmentInvalid() {
        this.latitude = 8388609.0f;
        this.dryBulbTemp = 32769.0f;
        this.stationPress = 1.6777215E7f;
        this.relativeHum = 65535.0f;
        this.densityAltitude = 8388609.0f;
        this.autoUpdateEnable = (byte) -1;
        this.spinDriftEnable = (byte) -1;
        this.coriolisEnable = (byte) -1;
        this.aeroJumpEnable = (byte) -1;
        this.windCaptureAll = (byte) -1;
    }
}
