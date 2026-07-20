package com.nkhome.link.ballistics.nkmassdata;

public abstract class o {
    private Float ballisticCoefficient;
    private Float boreHeight;
    private Float bulletDiameter;
    private Float bulletWeight;
    private Integer clickValE;
    private Integer clickValW;
    private Float dof;
    private Integer eClicks;
    private Integer eUnits;
    private Float holdover;
    private Float incAngle;
    private Float latitude;
    private Float muzzleVelocity;
    private String profileName;
    private Float range;
    private Float relativeHumidity;
    private Float stationPressure;
    private Float temp;
    private Float twistRate;
    private int validFlags;
    private Integer wClicks;
    private Integer wUnits;
    private Float windDirection;
    private Float windSpeed1;
    private Float windSpeed2;
    private Float windage1;
    private Float windage2;
    private Float zeroRange;

    public o(String str, int i2, int i4, int i5, int i6, int i7, int i8, int i9) {
        this.profileName = str;
        this.validFlags = i2;
        this.eUnits = Integer.valueOf(i4);
        this.wUnits = Integer.valueOf(i5);
        this.clickValE = Integer.valueOf(i6);
        this.clickValW = Integer.valueOf(i7);
        this.eClicks = Integer.valueOf(i8);
        this.wClicks = Integer.valueOf(i9);
    }

    public final void B(Float f4, int i2) {
        this.ballisticCoefficient = (Float) V(f4, i2);
    }

    public final void C(Float f4, int i2) {
        this.boreHeight = (Float) V(f4, i2);
    }

    public final void D(Float f4, int i2) {
        this.bulletDiameter = (Float) V(f4, i2);
    }

    public final void E(Float f4, int i2) {
        this.bulletWeight = (Float) V(f4, i2);
    }

    public final void F(Float f4) {
        this.dof = (Float) V(f4, 1);
    }

    public final void G(Float f4) {
        this.holdover = (Float) V(f4, 2);
    }

    public final void H(Float f4) {
        this.incAngle = (Float) V(f4, 20);
    }

    public final void I(Float f4) {
        this.latitude = (Float) V(f4, 8);
    }

    public final void J(Float f4) {
        this.muzzleVelocity = (Float) V(f4, 12);
    }

    public final void K(Float f4) {
        this.range = (Float) V(f4, 0);
    }

    public final void L(Float f4) {
        this.relativeHumidity = (Float) V(f4, 11);
    }

    public final void M(Float f4) {
        this.stationPressure = (Float) V(f4, 10);
    }

    public final void N(Float f4) {
        this.temp = (Float) V(f4, 9);
    }

    public final void O(Float f4, int i2) {
        this.twistRate = (Float) V(f4, i2);
    }

    public final void P(Float f4) {
        this.windDirection = (Float) V(f4, 7);
    }

    public final void Q(Float f4) {
        this.windSpeed1 = (Float) V(f4, 5);
    }

    public final void R(Float f4) {
        this.windSpeed2 = (Float) V(f4, 6);
    }

    public final void S(Float f4) {
        this.windage1 = (Float) V(f4, 3);
    }

    public final void T(Float f4) {
        this.windage2 = (Float) V(f4, 4);
    }

    public final void U(Float f4) {
        this.zeroRange = (Float) V(f4, 13);
    }

    public final Number V(Number number, int i2) {
        if (((this.validFlags >> i2) & 1) == 0) {
            return null;
        }
        return number;
    }

    public final String l() {
        return this.profileName;
    }

    public final Integer y() {
        return this.eUnits;
    }

    public final Integer A() {
        return this.wUnits;
    }
}
