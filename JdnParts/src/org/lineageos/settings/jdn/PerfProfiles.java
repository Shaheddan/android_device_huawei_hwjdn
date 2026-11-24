/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.jdn;

import android.app.ActivityManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemProperties;
import android.provider.DeviceConfig;
import android.provider.Settings;
import android.util.Log;

import java.io.BufferedReader;
import java.io.FileReader;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

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

    // ---- Memory ----------------------------------------------------------------------

    /**
     * The Memory part of the page.
     *
     *  - Compressed RAM (zram) and swap to storage: persist.vendor.kiwi.perf.zram holds the
     *    zram size in percent of RAM, persist.vendor.kiwi.perf.swap the size of the swap file
     *    on /data in MB (0 = off). Vendor init reads both once per boot, turns zram on from
     *    /vendor/etc/fstab.zram<percent> and starts jdn-swapfile.sh for the file, then
     *    reports what is in use in vendor.kiwi.perf.zram and vendor.kiwi.perf.swap (the swap
     *    one can also be "nospace" or "failed"). Nothing chosen means 75% and no swap file,
     *    see init.target.rc. The 3.10 kernel has no zram writeback, so the file is plain swap
     *    that only fills once zram is full.
     *  - Background apps: how many cached processes ActivityManager keeps
     *    (activity_manager/max_cached_processes). Applies right away and stays across
     *    restarts. "balanced" removes the override, so the tablet's overlay value
     *    (config_customizedMaxCachedProcesses) counts again.
     */
    static final class Memory {
        static final String PROP_ZRAM = "persist.vendor.kiwi.perf.zram";
        static final String PROP_WB = "persist.vendor.kiwi.perf.swap";
        private static final String PROP_ZRAM_ACTIVE = "vendor.kiwi.perf.zram";
        private static final String PROP_WB_ACTIVE = "vendor.kiwi.perf.swap";
        /** Keep in step with init.target.rc ("vendor.kiwi.perf.zram=0"). */
        private static final int ZRAM_DEFAULT = 75;
        static final String SWAP_FILE = "/data/vendor/swap/swapfile";
        static final String WB_NOSPACE = "nospace", WB_FAILED = "failed";
        static final int[] ZRAM = {25, 50, 75, 100};
        static final int[] WB = {0, 512, 1024, 2048};
        static final String FEWER = "fewer", BALANCED = "balanced", MORE = "more";
        static final String[] APPS = {FEWER, BALANCED, MORE};
        private static final String NS_AM = "activity_manager";
        private static final String KEY_CACHED = "max_cached_processes";

        private Memory() {}

        private static boolean valid(int[] options, int v) {
            for (int o : options) {
                if (o == v) return true;
            }
            return false;
        }

        static int zramDefault() {
            return ZRAM_DEFAULT;
        }

        /** The zram size the next start uses. */
        static int zramChosen() {
            final int v = SystemProperties.getInt(PROP_ZRAM, 0);
            return valid(ZRAM, v) ? v : zramDefault();
        }

        /** The zram size this start uses (a ROM without the setting: what is chosen). */
        static int zramActive() {
            final int v = SystemProperties.getInt(PROP_ZRAM_ACTIVE, 0);
            return valid(ZRAM, v) ? v : zramChosen();
        }

        static int wbChosen() {
            final int v = SystemProperties.getInt(PROP_WB, 0);
            return valid(WB, v) ? v : 0;
        }

        /**
         * The swap file size this start uses. When the file could not be set up it counts as
         * the chosen size, so the page doesn't ask for a restart; wbProblem() tells why.
         */
        static int wbActive() {
            final int v = SystemProperties.getInt(PROP_WB_ACTIVE, -1);
            return valid(WB, v) ? v : wbChosen();
        }

        /** WB_NOSPACE or WB_FAILED when the swap file isn't on this start, else null. */
        static String wbProblem() {
            final String v = SystemProperties.get(PROP_WB_ACTIVE, "");
            return WB_NOSPACE.equals(v) || WB_FAILED.equals(v) ? v : null;
        }

        /** Bytes in the swap file right now, from /proc/swaps, or -1 when it isn't on. */
        static long swapFileUsed() {
            try (BufferedReader r = new BufferedReader(new FileReader("/proc/swaps"))) {
                String line;
                while ((line = r.readLine()) != null) {
                    // Filename Type Size Used Priority, sizes in kB
                    final String[] f = line.trim().split("\\s+");
                    if (f.length >= 4 && SWAP_FILE.equals(f[0])) {
                        return Long.parseLong(f[3]) * 1024L;
                    }
                }
            } catch (Exception e) {
                // Not readable: treat it as not on.
            }
            return -1;
        }

        static void choose(int zram, int wb) {
            SystemProperties.set(PROP_ZRAM, String.valueOf(zram));
            SystemProperties.set(PROP_WB, String.valueOf(wb));
        }

        /** Cached processes for fewer / balanced / more: half, this tablet's own, 1.5 times. */
        static int[] appsLimits(Context c) {
            int base = 32;
            final int id = c.getResources().getIdentifier("config_customizedMaxCachedProcesses",
                    "integer", "android");
            if (id != 0) base = c.getResources().getInteger(id);
            // Android's own default is 1024 (it freezes cached apps; this kernel can't).
            base = Math.max(16, Math.min(base, 128));
            return new int[] {base / 2, base, base * 3 / 2};
        }

        static String apps(Context c) {
            final String v = DeviceConfig.getProperty(NS_AM, KEY_CACHED);
            if (v == null || v.isEmpty()) return BALANCED;
            final int[] limits = appsLimits(c);
            try {
                final int n = Integer.parseInt(v.trim());
                if (n <= limits[0]) return FEWER;
                if (n >= limits[2]) return MORE;
            } catch (NumberFormatException e) {
                // Not one of ours: show it as the tablet's own setting.
            }
            return BALANCED;
        }

        static void chooseApps(Context c, String level) {
            final int[] limits = appsLimits(c);
            if (FEWER.equals(level)) {
                DeviceConfig.setProperty(NS_AM, KEY_CACHED, String.valueOf(limits[0]), false);
            } else if (MORE.equals(level)) {
                DeviceConfig.setProperty(NS_AM, KEY_CACHED, String.valueOf(limits[2]), false);
            } else {
                DeviceConfig.deleteProperty(NS_AM, KEY_CACHED);
            }
            Log.i(TAG, "background apps: " + level);
        }

        /** {MemTotal, MemAvailable, SwapTotal, SwapFree} in kB, from /proc/meminfo. */
        static long[] meminfo() {
            final long[] v = new long[4];
            final String[] keys = {"MemTotal:", "MemAvailable:", "SwapTotal:", "SwapFree:"};
            try (BufferedReader r = new BufferedReader(new FileReader("/proc/meminfo"))) {
                String line;
                while ((line = r.readLine()) != null) {
                    for (int i = 0; i < keys.length; i++) {
                        if (line.startsWith(keys[i])) {
                            v[i] = Long.parseLong(line.substring(keys[i].length())
                                    .replace("kB", "").trim());
                        }
                    }
                }
            } catch (Exception e) {
                // Leave zeros: the card shows dashes.
            }
            return v;
        }

        /** Numbers of a zram0 sysfs file (mm_stat), or null. */
        static long[] zramFile(String name) {
            try (BufferedReader r = new BufferedReader(new FileReader("/sys/block/zram0/" + name))) {
                final String line = r.readLine();
                if (line == null) return null;
                final String[] f = line.trim().split("\\s+");
                final long[] v = new long[f.length];
                for (int i = 0; i < f.length; i++) v[i] = Long.parseLong(f[i]);
                return v;
            } catch (Exception e) {
                return null;
            }
        }

        /**
         * Closes the apps that sit in the background (cached), except the home screen, the
         * keyboard and this app. Returns how many apps it closed. Not on the main thread.
         */
        static int freeUp(Context c) {
            final ActivityManager am = c.getSystemService(ActivityManager.class);
            final Set<String> keep = new HashSet<>();
            keep.add(c.getPackageName());
            final ResolveInfo home = c.getPackageManager().resolveActivity(
                    new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
                    PackageManager.MATCH_DEFAULT_ONLY);
            if (home != null && home.activityInfo != null) keep.add(home.activityInfo.packageName);
            final String ime = Settings.Secure.getString(c.getContentResolver(),
                    Settings.Secure.DEFAULT_INPUT_METHOD);
            final ComponentName imeName = ime == null ? null : ComponentName.unflattenFromString(ime);
            if (imeName != null) keep.add(imeName.getPackageName());

            final Set<String> close = new HashSet<>();
            final List<ActivityManager.RunningAppProcessInfo> procs = am.getRunningAppProcesses();
            if (procs != null) {
                for (ActivityManager.RunningAppProcessInfo p : procs) {
                    if (p.importance < ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED
                            || p.pkgList == null) {
                        continue;
                    }
                    for (String pkg : p.pkgList) {
                        if (!keep.contains(pkg)) close.add(pkg);
                    }
                }
            }
            for (String pkg : close) am.killBackgroundProcesses(pkg);
            Log.i(TAG, "free up RAM: closed " + close.size() + " apps");
            return close.size();
        }
    }
}
