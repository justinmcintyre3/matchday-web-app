package com.nkhome.link.ballistics.nkmassdata;

import androidx.annotation.Keep;
@Keep
/* loaded from: classes.dex */
public class BallisticsDataInput {
    private static final String SPEED_MS = "m/s";
    private static final String WIND_SPEED_PREFS_KEY = "wind_speed_units";
    public float directionOfFire;
    public byte doExtraCalcs;
    public byte dofIsValid;
    public byte incAngleIsValid;
    public float inclinationAngle;
    public float latitude;
    public byte latitudeIsValid;
    public byte rangeIsValid;
    public byte setAsActiveTgt;
    public byte solutionId;
    public byte targetNumIsValid;
    public byte targetNumber;
    public float targetRange;
    public float targetSpeed;
    public byte targetSpeedIsValid;
    public byte tgtMvmtDir;
    public byte tgtMvmtDirIsValid;
    public byte useCurrentTarget;
    public float windDirection;
    public byte windDirectionIsValid;
    public float windSpeed1;
    public byte windSpeed1IsValid;
    public float windSpeed2;
    public byte windSpeed2IsValid;

    public boolean isDataValid() {
        if (this.rangeIsValid != 0 && this.dofIsValid != 0 && this.incAngleIsValid != 0 && this.targetSpeedIsValid != 0 && this.windSpeed1IsValid != 0 && this.windSpeed2IsValid != 0 && this.windDirectionIsValid != 0) {
            return true;
        }
        return false;
    }

    public void setDefaultValues() {
        this.targetRange = 100.0f;
        this.inclinationAngle = 0.0f;
        this.directionOfFire = 0.0f;
        this.rangeIsValid = (byte) 1;
        this.incAngleIsValid = (byte) 1;
        this.dofIsValid = (byte) 1;
        this.useCurrentTarget = (byte) 1;
        this.targetNumber = (byte) 0;
        this.targetNumIsValid = (byte) 0;
        this.solutionId = (byte) 0;
        this.targetSpeed = 0.0f;
        this.windSpeed1 = 0.0f;
        this.windSpeed2 = 0.0f;
        this.windDirection = 0.0f;
        this.latitude = 45.0f;
        this.tgtMvmtDir = (byte) 0;
        this.tgtMvmtDirIsValid = (byte) 0;
        this.targetSpeedIsValid = (byte) 0;
        this.windSpeed1IsValid = (byte) 0;
        this.windSpeed2IsValid = (byte) 0;
        this.windDirectionIsValid = (byte) 0;
        this.latitudeIsValid = (byte) 0;
        this.doExtraCalcs = (byte) 0;
        this.setAsActiveTgt = (byte) 0;
    }

    public void setDirectionOfFire(float f4) {
        this.directionOfFire = f4;
    }

    public void setInclinationAngle(float f4) {
        this.inclinationAngle = f4;
    }

    public void setLatitude(float f4) {
        this.latitude = f4;
    }

    public void setSolutionId(byte b4) {
        this.solutionId = b4;
    }

    public void setTargetNumber(byte b4) {
        this.targetNumber = b4;
    }

    public void setTargetRange(float f4) {
        this.targetRange = f4;
    }

    public void setTargetSpeed(float f4) {
        this.targetSpeed = f4;
    }

    public void setTgtMvmtDir(byte b4) {
        this.tgtMvmtDir = b4;
    }

    public void setWindDirection(float f4) {
        this.windDirection = f4;
    }

    public void setWindSpeed1(float f4) {
        this.windSpeed1 = f4;
    }

    public void setWindSpeed2(float f4) {
        this.windSpeed2 = f4;
    }

    /** Sets validity flags using the same ranges as the Kestrel Link app validators. */
    public void applyDefaultValidation() {
        this.rangeIsValid = isRangeValid(this.targetRange) ? (byte) 1 : (byte) 0;
        this.incAngleIsValid = isInRange(this.inclinationAngle, -90.0f, 90.0f) ? (byte) 1 : (byte) 0;
        this.dofIsValid = isInRange(this.directionOfFire, 0.0f, 359.0f) ? (byte) 1 : (byte) 0;
        this.targetNumIsValid = isTargetNumberValid(this.targetNumber) ? (byte) 1 : (byte) 0;
        this.targetSpeedIsValid = isInRange(this.targetSpeed, 0.0f, 50.0f) ? (byte) 1 : (byte) 0;
        this.windSpeed1IsValid = isInRange(this.windSpeed1, 0.0f, 50.0f) ? (byte) 1 : (byte) 0;
        this.windSpeed2IsValid = isInRange(this.windSpeed2, 0.0f, 50.0f) ? (byte) 1 : (byte) 0;
        this.windDirectionIsValid = isInRange(this.windDirection, 0.0f, 359.0f) ? (byte) 1 : (byte) 0;
        this.latitudeIsValid = isInRange(this.latitude, -90.0f, 90.0f) ? (byte) 1 : (byte) 0;
        this.tgtMvmtDirIsValid = (byte) 1;
    }

    private static boolean isInRange(float value, float min, float max) {
        return value >= min && value <= max;
    }

    private static boolean isTargetNumberValid(float targetNumber) {
        return targetNumber >= 0.0f && targetNumber <= 9.0f;
    }

    private static boolean isRangeValid(float rangeMeters) {
        return rangeMeters >= 0.0f && rangeMeters <= 3657.6f;
    }
}
