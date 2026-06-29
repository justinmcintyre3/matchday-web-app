package com.nkhome.link.ballistics.nkmassdata;

import android.util.Log;
import androidx.annotation.Keep;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
@Keep
/* loaded from: classes.dex */
public class NkKestrel extends NkMassData {
    private boolean jniConnected = false;
    private k mListener;
    private int numAbGunsToTransfer;
    private int numAbGunsTransfered;

    public NkKestrel(k kVar) {
        this.mListener = kVar;
    }

    private native void connectKestrelClass();

    private native void disconnectKestrelClass();

    private static double getProgress(int i2, int i4) {
        return (i2 / i4) * 100.0d;
    }

    public void bootloadComplete(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.N(z4);
        }
    }

    public void connectJni() {
        if (!this.jniConnected) {
            Log.d("NK-Kestrel", "NkKestrel - connectJni()");
            connectKestrelClass();
            this.jniConnected = true;
            return;
        }
        Log.d("NK-Kestrel", "NkKestrel - connectJni() - jni already connected");
    }

    public void disconnectJni() {
        if (this.jniConnected) {
            Log.d("NK-Kestrel", "NkKestrel - disconnectJni()");
            resetMd();
            disconnectKestrelClass();
            this.jniConnected = false;
            return;
        }
        Log.d("NK-Kestrel", "NkKestrel - disconnectJni() - jni not connected");
    }

    public void encryptionStopped(boolean z4) {
        Log.d("NK-Kestrel", "NkKestrel callback - encryptionStopped: " + z4);
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.o(z4);
        }
    }

    public void gunWasErased(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.d(z4);
        }
    }

    public void gunWasSent(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.P(z4);
        }
    }

    public void rcvAuthRequestAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.c(z4);
        }
    }

    public void rcvCalcFullSolnAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.q(z4);
        }
    }

    public void rcvCurrentScreen(int i2) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.t(i2);
        }
    }

    public void rcvGetRemoteSolnAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.O(z4);
        }
    }

    public void rcvGetScreenAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.f(z4);
        }
    }

    public void rcvGetSettingsAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.v(z4);
        }
    }

    public void rcvGetWezDataAck(int i2) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.p(i2);
        }
    }

    public void rcvPrivacyAuthAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.e(z4);
        }
    }

    public void rcvPrivacyStatus(boolean z4) {
        Log.d("NK-Kestrel", "NkKestrel - rcvPrivacyStatus: " + z4);
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.G(z4);
        }
    }

    public void rcvSet2700Wind(float f4, float f5) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.W(f4, f5);
        }
    }

    public void rcvSetBalUnitsAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.k0(z4);
        }
    }

    public void rcvSetEnvironmentAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.F(z4);
        }
    }

    public void rcvSetRemoteSolnAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.I(z4);
        }
    }

    public void rcvSetScreenAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.o0(z4);
        }
    }

    public void rcvSetTgtInfoEodAck(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.c0(z4);
        }
    }

    public void rcvSetWezDataAck(int i2) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.j0(i2);
        }
    }

    public void rcvSysEvent(int i2) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.J(i2);
        }
    }

    public void rcvWezData(float f4, float f5, float f6, int i2) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.Z(f4, f5, f6, i2);
        }
    }

    public void receiveGun(int i2, int i4, int i5) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.g0(null);
        }
    }

    public void receivedAbAg(int i2) {
        this.numAbGunsTransfered = 0;
        this.numAbGunsToTransfer = i2;
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.L(i2);
        }
    }

    public void receivedAbAs(int i2) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.U(i2, 0.0, null);
        }
    }

    public void setBootloadProgress(float f4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.M(f4);
        }
    }

    public void updateAbSingleTargetData(boolean z4, int i2, int i4, int i5, int i6, int i7, int i8, int i9, float f4, float f5, float f6, float f7, float f8, float f9, float f10, float f11, float f12, float f13, float f14, float f15, float f16, float f17, float f18, float f19, float f20, float f21, float f22, float f23, float f24) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.S(z4, null);
        }
    }

    public void updateAuthComplete(boolean z4) {
        Log.d("NK-Kestrel", "NkKestrel - updateAuthComplete() - Authentication response: isAuthenticated = " + z4 + " ");
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.K(z4);
        }
    }

    public void updateBalFullSolution(float f4, float f5, float f6, float f7, float f8, float f9, float f10, float f11, float f12, float f13, float f14, float f15, float f16, float f17, float f18, float f19, float f20, float f21, float f22, float f23, float f24, float f25, float f26, float f27, int i2, int i4, int i5) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.z(null);
        }
    }

    public void updateBalInfoSettings(boolean z4, int i2, int i4, float f4, float f5, float f6, float f7, float f8, float f9, float f10, float f11, float f12, float f13, float f14, float f15, float f16, float f17, float f18, float f19, float f20, float f21, float f22, float f23, float f24, float f25, float f26, float f27, float f28, float f29, float f30, float f31, float f32, float f33, float f34, float f35, float f36, float f37, float f38, float f39, float f40) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.x(z4, null);
        }
    }

    public void updateBalSolution(float f4, float f5, float f6, float f7, float f8, float f9, int i2, int i4) {
        Log.d("NK-Kestrel", "NKKestrel updateBalSolution");
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.e0(f4, f5, f6, f7, f8, f9, i2, i4);
        }
    }

    public void updateDeviceName() {
        byte[] kestrelName = getKestrelName();
        k kVar = this.mListener;
        if (kVar != null && kestrelName != null) {
            kVar.E(new String(kestrelName));
        }
    }

    public void updateDeviceSN() {
        byte[] kestrelSN = getKestrelSN();
        k kVar = this.mListener;
        if (kVar != null && kestrelSN != null) {
            kVar.B(new String(kestrelSN));
        }
    }

    public void updateEnvironment(float f4, float f5, float f6, float f7, float f8, int i2, int i4, int i5, int i6, int i7) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.Q(f4, f5, f6, f7, f8, i2, i4, i5, i6, i7);
        }
    }

    public void updateFullInputs(float f4, float f5, float f6, int i2, float f7, float f8, float f9, float f10, float f11, int i4) {
        Log.d("NK-Kestrel", "NkKestrel - updateFullInputs - cmd 137 - callback");
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.X(f4, f5, f6, i2, f7, f8, f9, f10, f11, i4);
        }
    }

    public void updateGunTransferSettings(boolean z4, int i2, int i4, int i5, int[] iArr) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.A(z4, i2, i4, i5, iArr);
        }
    }

    public void updateHornadySingleTargetData(boolean z4, int i2, int i4, int i5, int i6, int i7, int i8, int i9, int i10, int i11, float f4, float f5, float f6, float f7, float f8, float f9, float f10, float f11, float f12, float f13, float f14, float f15, float f16, float f17, float f18, float f19, float f20, float f21, float f22, float f23) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.i(z4, null);
        }
    }

    public void updateNkPEXStatus(boolean z4) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.n0(z4);
        }
    }

    public void updateTgtInfoSettings(boolean z4, int i2, int i4, int i5, int i6) {
        k kVar = this.mListener;
        if (kVar != null) {
            kVar.k(z4, i2, i5, i4, i6);
        }
    }
}
