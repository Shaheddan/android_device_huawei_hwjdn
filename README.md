# Device tree for Huawei mediapad T2 8 pro (hwjdn) — LineageOS 19.1

Unofficial LineageOS 19.1 (Android 12L) for the Huawei mediapad T2 8 pro, ported
from this device's own LineageOS 18.1 tree.

## Device specifications

| Feature  | Specification                     |
| :------- | :-------------------------------- |
| SoC      | Qualcomm MSM8939v2 Snapdragon 616   |
| CPU      | 4x 1.7 GHz ARM Cortex-A53, 4x 1.2 GHz ARM Cortex-A53, Cores: 8  |
| GPU      | Qualcomm Adreno 405, 550 MHz                        |
| Memory   | 2 GB, 800 MHz                        |
| Display  | 8 in, IPS, 1920 x 1200 pixels, 24 bit                |
| Storage  | 16 GB (microSD, microSDHC, microSDXC support)           |
| Battery  | 4800 mAh, Li-Polymer                          |
| Kernel   | 3.10 (arm64, non-Treble)          |

## Supported models

| Model | Board ID | Status |
| :---- | :------- | :----- |
| JDN-L01 (LTE) | `0x1f94` | Supported and tested |
| JDN-W09 (Wi-Fi) | `0x1f92` | `jdn-pad-power` branch — not yet tested on a W09 |
| JDN-AL00 (China, LTE) | `0x1fc2` | `jdn-pad-power` branch — not yet tested on an AL00 |

The bootloader picks the DTB whose board ID matches, so the `lineage-19.1`
release, which carries only the L01's DTB, cannot boot a W09 or AL00. The
`jdn-pad-power` kernel builds one DTB per model from Huawei's own JDN
source: the W09 and AL00 trees include the L01's and override only what
Huawei's differ in (model, board ID, modem ID, no SAR sensor, the variant
name in the identity nodes, and the W09 panel's front porches). `init`
reads the variant name back from `/proc/app_info` and sets the model.

The installer checks that TrustZone is `TZ.BF.3.0.C3-00025`, the version on
the L01. If a W09 or AL00 refuses the zip on that check, please report it.

## Status

Boots **SELinux enforcing** with a clean denial log. Working: RIL (calls,
SMS, data), Wi-Fi including toggle/reconnect, Bluetooth with A2DP audio,
camera, audio, sensors (accelerometer, light, proximity), GPS, MTP/ADB,
lockscreen, brightness and auto-brightness.

### Known limitations

- **Rear-camera HDR** fails in the stock Camera2 app. AOSP's Camera2→HAL1
  legacy shim calls `startPreview` while the HAL is still in `PIC_TAKING`;
  the longer rear-sensor HDR capture lands inside that window. The HAL is
  fine — any Camera API1 app (e.g. Open Camera) does HDR correctly.
- Flashing over an existing `/data` may leave stale SELinux labels on
  `/data/media`, which stops photos saving. Fix once with
  `adb shell restorecon -RF /data/media`.

## Changes on the `jdn-pad-power` branch

Huawei's kernel source for this tablet (the `JDN-W09_MM_EMUI4.0` open-source
package) was not available when this port started. Once a JDN-W09 owner
shared it, every source file this kernel actually builds was compared with
Huawei's copy, and the differences that matter were ported here and in the
[kernel](https://github.com/Shaheddan/android_kernel_huawei_hwjdn/tree/jdn-pad-power).
The same branch also takes on the bugs that owner reported (the shift after
sleep, lag, slow charging); the CPU-core fix is the one kiwi got on
LineageOS 20.

| Change | Why | Tested |
| :----- | :-- | :----- |
| Huawei's pad panel power sequence (kernel) | The image woke up shifted a few rows after sleep, on the W09 and the L01. | L01: 6/6 wakes, no shift |
| All CPU cores online while the screen is on | `core_ctl` parked most cores and confined system_server, SurfaceFlinger, SystemUI and the launcher to two of them, so most apps lagged. The power HAL's screen on/off hook now sets `min_cpus` 4/4 with the screen on and the stock 0/1 with it off. | L01, at runtime |
| CFQ as the default I/O scheduler (kernel) | The tablet ran noop: `sys.io.scheduler` does nothing on 19.1. CFQ is the only scheduler here that honours the I/O priorities Android gives background work. | L01, at runtime |
| Touch controller interrupt instead of polling (kernel) | Polling every 15 ms added up to 15 ms of latency plus jitter. | L01, at runtime |
| Wall-charger input limit 1000 → 2000 mA (kernel DT) | With Huawei's own 2 A charger the battery got about 0.4 A with the screen on. | In the next test build |
| HI843 O-Film camera OTP calibration (kernel) | The camera HAL found no white-balance calibration for the rear module; it lives in sensor OTP, which our kernel never read. | In the next test build |
| `IP_MULTICAST` and `PM_WAKELOCKS_GC` (kernel) | Huawei's defconfig enables both; multicast is needed for mDNS, Cast and DLNA discovery. | In the next test build |
| JDN-W09 and JDN-AL00 support (kernel + `init`) | See *Supported models*. | Needs W09/AL00 owners |
| DSI command-injection sysfs removed (kernel) | A root-writable bring-up tool that shipped in the 19.1 release. | — |

Checked and left as they are: the GPU driver (no Huawei changes), the
battery profile and battery-ID map (identical to Huawei's) and the rest of
Huawei's display changes.

## Extras

- **Bypass charging** (JdnParts): Settings → Battery → Bypass charging,
  restyled for Android 12 with a collapsing toolbar and system dark mode.
  Manual mode holds the current battery level; auto mode charges to a
  configurable threshold and holds there. Backed by the BQ24296 charger
  IC's charge-disable path (`factory_diag` sysfs node).

## Notable 18.1 → 19.1 changes

- **Kernel is no longer stock.** Android 12's keystore2 authorizes callers
  via `getCallingSid()`, which needs `FLAT_BINDER_FLAG_TXN_SECURITY_CTX` —
  absent from the stock 3.10 binder, so every unlock was denied. A modern
  binder driver was transplanted in, with `READ_ONCE`/`WRITE_ONCE` and
  `wake_up_pollfree` backported to support it.
- `CONFIG_RT_GROUP_SCHED` disabled: Android 12 dropped init's RT-bandwidth
  writes, leaving every child cgroup at `rt_runtime_us=0` and aborting
  Bluetooth at `timer_create(CLOCK_BOOTTIME)`.
- prima restores `con_mode` to STA when a SoftAP adapter is closed —
  Android 12's Wi-Fi HAL deletes the AP interface instead of switching it
  back, which left the driver stuck creating `softap.0` and never `wlan0`.
- Camera: `TARGET_HAS_LEGACY_CAMERA_HAL1` (the blob is 32-bit only), plus
  the composer registering `display.qservice` on `/dev/binder`.
- Telephony: LineageOS `simactivation` patch, required for the legacy modem
  to activate its UICC subscription apps.
- LiveDisplay removed: `libmm-abl.so` needs `android::IPowerManager::
  asInterface`, which Android 12 removed when PowerManager went AIDL.
- Keymaster 4.1, clearkey 1.4, Wi-Fi overlay moved to
  `packages/modules/Wifi` (resources became a mainline module).
- SELinux policy now uses TipzTeam's `device/qcom/sepolicy-legacy`, which
  has a real `msm8916` directory and reached enforcing on this platform.
- `ro.kernel.ebpf.supported=false` is set from the product rather than a
  vendor rc: `vendor_init` may not set `default_prop`, and without it the
  critical `bpfloader` service fails and reboots the device.

## Building

Branches of this tree: `main` is the TWRP 3.7.0 tree, `lineage-19.1` the
LineageOS 19.1 release, and `jdn-pad-power` the release plus the Huawei
source work above (under test).

`manifests/` pulls in everything outside the LineageOS manifest: this tree,
the kernel (at `kernel/huawei/jdn`), the vendor blobs, kiwi's device and
vendor trees (hwjdn uses kiwi's `libwcnss_qmi`, which
`hardware/qcom-caf/wlan` links by name; kiwi itself is not built),
`device/qcom/sepolicy-legacy`, the msm8916 CAF HALs and `dtbtool`.

`patches/lineage-19.1/` holds the platform patches the 19.1 release was
built with, one folder per project path. Among them: camera HAL1 support
(`frameworks/av`, `frameworks/base`, `hardware/interfaces`,
`hardware/lineage/interfaces`, `system/core`, `vendor/lineage`), legacy RIL
and SIM activation (`frameworks/opt/telephony`), the Wi-Fi WPA3
transition-disable fix (`packages/modules/Wifi`), 3.10-kernel fixes
(`system/bpf`, `system/netd`, `art`, `external/perfetto`), legacy
FunctionFS for adb, SurfaceFlinger, `libbfqio` for the CAF msm8916 HALs, and
sepolicy. `apply-patches.sh` skips any patch whose subject is already in the
project's history, so running it twice is safe.
The two loose patches directly in `patches/` are the original pair from the
first release; both are covered — the Wi-Fi one is in the set and the
sepolicy-legacy one is already on its `lineage-19.1` branch.

    repo init -u https://github.com/LineageOS/android.git -b lineage-19.1 --git-lfs
    mkdir -p .repo/local_manifests
    curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/jdn-pad-power/manifests/hwjdn.xml -o .repo/local_manifests/hwjdn.xml
    curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/jdn-pad-power/manifests/hwjdn-support.xml -o .repo/local_manifests/hwjdn-support.xml
    repo sync
    bash device/huawei/hwjdn/patches/apply-patches.sh
    source build/envsetup.sh
    lunch lineage_hwjdn-userdebug
    mka bacon

Build `userdebug`; the sepolicy tree only relaxes neverallows for
eng/userdebug.

### On crave.io

`crave/build-hwjdn.sh` runs the same steps on a Crave build node. Crave has
no LineageOS 19.1 project, so start it from a folder set up for the LOS 20
project, which the script re-initialises to 19.1:

    repo init -u https://github.com/accupara/los20.git -b lineage-20.0 --git-lfs
    crave run --no-patch -- "curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/jdn-pad-power/crave/build-hwjdn.sh | bash"

## Kernel / vendor

- Kernel: [android_kernel_huawei_hwjdn](https://github.com/Shaheddan/android_kernel_huawei_hwjdn)
  — `lineage-19.1` (release) and `jdn-pad-power` (this work), **modified**,
  see above
- Vendor: [proprietary_vendor_huawei_hwjdn](https://github.com/Shaheddan/proprietary_vendor_huawei_hwjdn)
  (`lineage-19.1`) — extracted from Huawei's stock firmware (EMUI 4,
  Android 6.0.1); `rmt_storage` is kiwi's dynamically linked build, because
  the stock static one cannot read Android 12's properties

## Credits

- LineageOS team (17.1 hwjdn tree, msm8916 platform work)
- [TipzTeam](https://codeberg.org/TipzTeam) — `sepolicy-legacy`,
  msm8916-common and wt88047x trees, the main 19.1 references
- niclimcy's wt88047x trees and the cyanogen/Motorola msm8916-common
  trees, used as references throughout the original 18.1 port
- Huawei, for the JDN kernel source, and the JDN-W09 owner who shared it
  and reported the W09 bugs
