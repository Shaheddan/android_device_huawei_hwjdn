/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.jdn;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemProperties;
import android.util.Log;

/**
 * The performance profiles of Settings > System > Performance.
 *
 * How a profile gets applied (all of it outside this app, see init.qcom.power.rc):
 *  - persist.vendor.kiwi.perf.profile holds the choice. When boot completes, init copies it
 *    to vendor.kiwi.perf.apply and sets the kernel's touch boost (cpu_boost) and the
 *    vendor.kiwi.perf.* values the power HAL boosts with.
 *  - The kernel always boots at the stock clocks; the overclock profiles raise the limits
 *    after boot.
 *  - Overclock guard: every boot on oc1/oc2 sets persist.vendor.kiwi.perf.trial=1. This app
 *    clears it after 3 good minutes or on a clean shutdown (so does init on shutdown). If
 *    init still finds it set at the next boot, the tablet restarted by itself: it uses Max
 *    instead and puts the overclock it turned off in vendor.kiwi.perf.fallback.
 *
 * The clocks shown here match init.qcom.power.rc and the kernel: keep them in step.
 */
final class PerfProfiles {

    private static final String TAG = "JdnPerf";

    static final String PROP_PROFILE = "persist.vendor.kiwi.perf.profile";
    static final String PROP_ACTIVE = "vendor.kiwi.perf.apply";
    static final String PROP_FALLBACK = "vendor.kiwi.perf.fallback";
    static final String PROP_TRIAL = "persist.vendor.kiwi.perf.trial";

    static final String DEFAULT = "smooth";
    static final long GUARD_MS = 3 * 60 * 1000;

    /** One profile; clocks in MHz as {little, big, gpu}. */
    static final class Profile {
        final String id;
        final int title, desc, level;
        final boolean oc;
        final int[] cap;      // the speed limits
        final int[] touch;    // floors while touching; null = none (stock) or full speed (max)

        Profile(String id, int title, int desc, int level, boolean oc, int[] cap, int[] touch) {
            this.id = id;
            this.title = title;
            this.desc = desc;
            this.level = level;
            this.oc = oc;
            this.cap = cap;
            this.touch = touch;
        }
    }

    /** The profiles of one SoC, mildest first. */
    static final class Soc {
        final String chip;
        final int[] stock;
        final Profile[] profiles;

        Soc(String chip, int[] stock, int[] oc1, int[] oc2, int[] light, int[] smooth, int[] fast) {
            this.chip = chip;
            this.stock = stock;
            profiles = new Profile[] {
                new Profile("stock", R.string.perf_stock, R.string.perf_stock_desc, 0, false, stock, null),
                new Profile("light", R.string.perf_light, R.string.perf_light_desc, 1, false, stock, light),
                new Profile("smooth", R.string.perf_smooth, R.string.perf_smooth_desc, 2, false, stock, smooth),
                new Profile("fast", R.string.perf_fast, R.string.perf_fast_desc, 3, false, stock, fast),
                new Profile("max", R.string.perf_max, R.string.perf_max_desc, 4, false, stock, null),
                new Profile("oc1", R.string.perf_oc1, R.string.perf_oc1_desc, 5, true, oc1, null),
                new Profile("oc2", R.string.perf_oc2, R.string.perf_oc2_desc, 6, true, oc2, null),
            };
        }

        Profile get(String id) {
            for (Profile p : profiles) {
                if (p.id.equals(id)) return p;
            }
            return get(DEFAULT);
        }
    }

    /*
     * MSM8939 (Snapdragon 616): little = the efficient cluster (cpu4-7, 1209.6 MHz),
     * big = the fast one (cpu0-3, 1497.6 MHz), Adreno 405 at 550 MHz. Overclock 1 is
     * 1305.6 / 1651.2 MHz, Overclock 2 1363.2 / 1708.8 MHz with the GPU at 620 MHz.
     */
    private static final Soc MSM8939 = new Soc("Snapdragon 616",
            new int[] {1210, 1498, 550},
            new int[] {1306, 1651, 550},
            new int[] {1363, 1709, 620},
            new int[] {998, 1114, 400},
            new int[] {1114, 1344, 400},
            new int[] {1210, 1459, 465});

    private static final Handler sHandler = new Handler(Looper.getMainLooper());
    private static final Runnable sConfirm = PerfProfiles::confirmTrial;

    private PerfProfiles() {}

    static Soc soc() {
        return MSM8939;
    }

    private static boolean known(String id) {
        for (Profile p : MSM8939.profiles) {
            if (p.id.equals(id)) return true;
        }
        return false;
    }

    /** The profile this boot runs with. */
    static String active() {
        final String id = SystemProperties.get(PROP_ACTIVE, "");
        return known(id) ? id : DEFAULT;
    }

    /** The profile the next boot will use. */
    static String chosen() {
        final String id = SystemProperties.get(PROP_PROFILE, "");
        return known(id) ? id : DEFAULT;
    }

    /** The overclock profile the guard turned off this boot, or "". */
    static String fallback() {
        final String id = SystemProperties.get(PROP_FALLBACK, "");
        return known(id) ? id : "";
    }

    /** A deliberate restart is coming: it is not a crash, so close any open trial too. */
    static void choose(String id) {
        SystemProperties.set(PROP_PROFILE, id);
        confirmTrial();
    }

    /** The tablet ran fine on an overclock profile: keep it. */
    static void confirmTrial() {
        if ("1".equals(SystemProperties.get(PROP_TRIAL, ""))) {
            SystemProperties.set(PROP_TRIAL, "0");
            Log.i(TAG, "overclock trial passed, keeping " + chosen());
        }
    }

    /** At boot completed: an overclock trial counts as good after GUARD_MS. */
    static void onBootCompleted(Context context) {
        if ("1".equals(SystemProperties.get(PROP_TRIAL, ""))) {
            sHandler.removeCallbacks(sConfirm);
            sHandler.postDelayed(sConfirm, GUARD_MS);
        }
    }
}
