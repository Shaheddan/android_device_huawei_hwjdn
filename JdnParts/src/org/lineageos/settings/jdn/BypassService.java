package org.lineageos.settings.jdn;

import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.os.BatteryManager;
import android.os.IBinder;
import android.preference.PreferenceManager;
import android.util.Log;

import java.io.BufferedReader;
import java.io.FileOutputStream;
import java.io.FileReader;

/**
 * Holds the battery level while the charger keeps powering the tablet, through the BQ24296's
 * factory_diag node (0 = charging off, input path still on; 1 = normal charging).
 *
 * The service runs for as long as JdnParts' persistent process does: it is started at boot and
 * whenever the bypass page is shown or left, and it never stops itself. It used to stop on
 * unplug and rely on ACTION_POWER_CONNECTED to come back, but since Android 8 that broadcast
 * is not delivered to manifest receivers, so after the first unplug it only came back when the
 * bypass page was left (screen off or back). ACTION_BATTERY_CHANGED, registered here at
 * runtime, already reports every plug and unplug.
 */
public class BypassService extends Service {
    private static final String TAG = "JdnBypass";
    private static final String NODE = "/sys/class/power_supply/battery/factory_diag";
    private static final int HYSTERESIS = 2;

    private boolean mBypassActive = false;
    private Intent mLastBattery;
    private SharedPreferences mPrefs;

    private final BroadcastReceiver mBatteryReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            mLastBattery = intent;
            evaluate();
        }
    };

    // A field, not a lambda passed inline: SharedPreferences keeps listeners weakly.
    // The page writes these keys in this same process, so a switch takes effect at once
    // instead of with the next battery broadcast (which can be minutes away).
    private final SharedPreferences.OnSharedPreferenceChangeListener mPrefsListener =
            (prefs, key) -> {
                if (key != null && key.startsWith("bypass_")) evaluate();
            };

    @Override
    public void onCreate() {
        super.onCreate();
        // Start from what the charger really does, so a node left at 0 is released if needed.
        mBypassActive = "0".equals(readNode());
        mPrefs = PreferenceManager.getDefaultSharedPreferences(
                createDeviceProtectedStorageContext());
        mPrefs.registerOnSharedPreferenceChangeListener(mPrefsListener);
        mLastBattery = registerReceiver(mBatteryReceiver,
                new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        evaluate();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Every start (boot, bypass page) re-applies the current settings right away.
        evaluate();
        return START_STICKY;
    }

    private void evaluate() {
        if (mLastBattery == null || mPrefs == null) return;
        boolean now = mPrefs.getBoolean("bypass_now", false);
        boolean auto = mPrefs.getBoolean("bypass_auto", false);
        int threshold = mPrefs.getInt("bypass_threshold", 80);

        int level = mLastBattery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        int plugged = mLastBattery.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0);

        if (plugged == 0 || level < 0 || (!now && !auto)) {
            // Unplugged or switched off: normal charging, but keep running for the next plug.
            setBypass(false);
            return;
        }

        if (now) {
            // Mode 1: hold at whatever level we're at, right now
            setBypass(true);
            return;
        }

        // Mode 2: charge normally until threshold, then hold there
        if (level >= threshold) {
            setBypass(true);
        } else if (level <= threshold - HYSTERESIS) {
            setBypass(false);
        }
        // Between threshold-HYSTERESIS and threshold: keep current state (no flapping)
    }

    private void setBypass(boolean on) {
        if (mBypassActive == on) return;
        mBypassActive = on;
        writeNode(on ? "0" : "1");
        Log.i(TAG, "Bypass charging " + (on ? "engaged" : "released"));
    }

    static void writeNode(String value) {
        try (FileOutputStream fos = new FileOutputStream(NODE)) {
            fos.write(value.getBytes());
        } catch (Exception e) {
            Log.e(TAG, "Failed to write " + NODE, e);
        }
    }

    private static String readNode() {
        try (BufferedReader br = new BufferedReader(new FileReader(NODE))) {
            String line = br.readLine();
            return line == null ? "" : line.trim();
        } catch (Exception e) {
            Log.e(TAG, "Failed to read " + NODE, e);
            return "";
        }
    }

    @Override
    public void onDestroy() {
        unregisterReceiver(mBatteryReceiver);
        if (mPrefs != null) mPrefs.unregisterOnSharedPreferenceChangeListener(mPrefsListener);
        writeNode("1");
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) { return null; }
}
