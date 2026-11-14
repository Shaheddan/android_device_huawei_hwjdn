# Device tree for Huawei MediaPad T2 8.0 Pro (hwjdn) — LineageOS 22.2

Unofficial LineageOS 22.2 (Android 15) for the Huawei MediaPad T2 8.0 Pro
(Honor Pad 2), running on the tablet's 3.10 kernel with eBPF, PSI and
cgroup v2 backported. It is this tree's LineageOS 21 port plus everything the
Honor 5X (kiwi) LineageOS 22.2 port needed to run Android 15 on the same SoC
and the same kernel lineage. The ROM is a userdebug build and runs with
SELinux enforcing.

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
| JDN-L01 (LTE) | `0x1f94` | Developer's unit |
| JDN-W09 (Wi-Fi) | `0x1f92` | Own DTB and `init` entry; not yet tested on a W09 |
| JDN-AL00 (China, LTE) | `0x1fc2` | Own DTB and `init` entry; not yet tested on an AL00 |

The bootloader picks the DTB whose board ID matches, and the kernel builds
one per model from Huawei's own JDN source. `init` reads the variant name
back from `/proc/app_info` and sets the model. The installer checks that
TrustZone is `TZ.BF.3.0.C3-00025`, the version on the L01; if a W09 or AL00
refuses the zip on that check, please report it.

## Status

**Works on the JDN-L01** and runs **fully SELinux enforcing** (no permissive
domains). Built and tested on 2026-11-14.

**Tested on 22.2**

- Calls (outgoing and incoming), incoming SMS, mobile data
- Camera (front and back), video recording and flashlight
- Video thumbnails and playback in Gallery
- ADB and `adb root`
- SELinux enforcing

**Not retested on 22.2 yet** (all of them worked on 21): Wi-Fi, Bluetooth,
Wi-Fi hotspot, GPS, auto-rotation and auto-brightness, audio, MTP, and the
new Battery health page.

LineageOS 21 stays available on branch `lineage-21`. Flash either with TWRP
[`hwjdn-twrp-20261018-0447`](https://github.com/Shaheddan/android_device_huawei_hwjdn/releases/tag/hwjdn-twrp-20261018-0447).

## Extras

- **Battery health** (JdnParts): Settings → Battery → Battery health. A
  Pixel-style page with a Normal / Reduced status, a Battery capacity card
  and battery tips. The tablet's fuel gauge can't measure real capacity, so
  the capacity is an estimate from the battery's age and the charge cycles
  the kernel now counts (against the 4650 mAh design capacity the fuel gauge
  reports), and the page says so. Tell it when the battery was new under
  Battery capacity; cycle counting starts with the first 22.2 boot.
- **Charging optimization** (inside Battery health): the bypass charging from
  earlier versions, redesigned for Android 15. "Limit to N%" charges up to a
  level and holds it there, "Hold current level" stops charging where it is.
  It uses the BQ24296 charger's charge-disable path (`factory_diag` sysfs
  node), and normal charging always comes back when you unplug.
- **Smoothness**: all cores stay online while the screen is on and get parked
  when it turns off (the power HAL's screen on/off hook,
  `power/power-interactive-ext.c`), and the eMMC uses the CFQ I/O scheduler.

## What changed from 21 (device tree)

- Shims: the 22.2 linker no longer supports `TARGET_LD_SHIM_LIBS`, so the
  shims are now patched into the blobs themselves as `DT_NEEDED` entries (in
  the vendor repo): thermal-engine, both imx219 pad chromatix libraries,
  libdmd, libbtaddr and libmm-abl.
- Camera: LineageOS 22.2 dropped the legacy HIDL camera device and provider;
  they now come from kiwi's tree (`camera-legacy/`), and the HALv1 framework
  patches are ported to Android 15 QPR2. The JPEG encoder stays loaded once
  used (`RTLD_NODELETE`): unloading it left a thread-local destructor behind,
  and closing the camera after a photo crashed the camera provider and
  cameraserver.
- Telephony: every variant runs single SIM. The dual-SIM setup `init`
  inherited from kiwi's tree started a second rild, and on 22.2 telephony
  retried a command on that empty second slot in a tight loop
  (`com.android.phone` near 100 % CPU).
- Bluetooth: libbt-vendor gets its own Soong namespace.
- OTA: non-A/B is set explicitly (`AB_OTA_UPDATER := false`).
- Build: ril-wrapper takes `telephony/ril.h` from `ril_headers`, and the
  recovery updater takes the edify and updater headers from
  `bootable/deprecated-ota`.
- SELinux, from an enforcing boot with everything in use: system_server may
  read `ro.bootimage.*`; dontaudits for probes that fall back (the AIDL
  graphics allocator lookup, ueventd's device tree fstab probe, the software
  codecs looking for the display stack's vendor libraries, a camera HAL
  property); the dontaudit for the old shim-path probe is gone; a dead
  `hbd` setprop and the unused `signinfolistener` service are removed.
- Battery: the kernel counts charge cycles in the vm-bms and reports them
  through the charger's `cycle_count`, which Battery health uses.
- Manifests: `hwjdn.xml` lists only the three hwjdn repositories;
  `hwjdn-kiwi.xml` and `hwjdn-support.xml` add what the tablet takes from kiwi
  in a tree that doesn't build kiwi.

The Android 13 and 14 changes and the work ported from Huawei's JDN source
are described in the README on the `lineage-21` branch.

## Platform patches

Android 15 needs changes outside the device tree for this tablet. They're in
`patches/lineage-22.2/` (38 patches, one folder per repository) and get
applied with `patches/apply-patches.sh lineage-22.2`. It is kiwi's 22.2 set
without its core-parking power patch, since this tree parks cores through
`TARGET_POWERHAL_SET_INTERACTIVE_EXT`:

- **frameworks/av, frameworks/base**: camera HALv1 support (Camera1 API, the
  legacy Camera2 shim and flash control), ported to Android 15 QPR2
- **frameworks/opt/telephony**: SIM activation for the legacy Qualcomm RIL
  (`ro.telephony.ril.config=simactivation`); without it incoming calls,
  incoming SMS and call state never show up
- **packages/modules/Wifi**: ignore WPA3 "transition disable" when the driver
  has no SAE support
- **build/make, build/soong**: the release ART runtime option, 32-bit
  cameraserver, and keeping library folders out of Soong's generated
  filesystems
- **hardware/qcom-caf (common, msm8916 audio/display/media, wlan),
  hardware/interfaces**: build fixes for the msm8916 HALs on Android 15
- **vendor/qcom/opensource/power**: msm8916 support
- **system/core, external/icu, vendor/lineage, device/lineage/sepolicy**:
  adaptations for the 3.10 kernel and this hardware

## Building

`manifests/hwjdn.xml` adds this tree, the kernel (at `kernel/huawei/jdn`) and
the vendor blobs. `hwjdn-kiwi.xml` adds kiwi's device and vendor trees
(hwjdn uses kiwi's `libwcnss_qmi` and legacy camera HALs; kiwi itself is not
built) and `device/qcom/sepolicy-legacy`; `hwjdn-support.xml` adds the
msm8916 CAF HALs and `dtbtool`.

    repo init -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs -g default,-pixel-extra
    mkdir -p .repo/local_manifests
    for m in hwjdn hwjdn-kiwi hwjdn-support; do
      curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/lineage-22.2/manifests/$m.xml -o .repo/local_manifests/$m.xml
    done
    repo sync
    bash device/huawei/hwjdn/patches/apply-patches.sh lineage-22.2
    source build/envsetup.sh
    lunch lineage_hwjdn-bp1a-userdebug
    mka bacon

In a tree that also builds kiwi, use `hwjdn.xml` alone next to kiwi's
`kiwi.xml` and `kiwi-support.xml`: they already declare the same projects,
and repo refuses a project declared twice.

Build `userdebug`; the sepolicy tree only relaxes neverallows for
eng/userdebug.

`--git-lfs` matters: the WebView APKs are Git LFS files. If
`external/chromium-webview/prebuilt/arm64/webview.apk` is only a small text
pointer, run `git lfs pull` in `prebuilt/arm64` and `prebuilt/arm`; the build
otherwise fails near the end with "not a valid zip file".

### Memory

This build was made on a 16 GB machine with local, unpublished low-RAM
changes to Soong, Blueprint and Kati that skip test, benchmark and fuzz
modules and hide test-only folders, and with `SOONG_BUILD_GOMEMLIMIT=11GiB`.
Machines with 32 GB or more should not need them.

## Installing

Flash the zip from TWRP. Coming from another ROM or another Android version,
wipe data first. If you use Magisk, flash it again after every ROM update,
since the update replaces the patched boot image.

## Branches

| Branch | Contents |
| :----- | :------- |
| `main` | TWRP 3.7.0 device tree |
| `twrp-variants` | TWRP with the W09 and AL00 DTBs (works on the L01; W09/AL00 untested) |
| `lineage-19.1` | LineageOS 19.1 release |
| `jdn-pad-power` | LineageOS 19.1 with the Huawei JDN source work (works on the L01) |
| `lineage-20` | LineageOS 20 (works on the L01) |
| `lineage-21` | LineageOS 21 (works on the L01) |
| `lineage-22.2` | LineageOS 22.2 (this branch, works on the L01) |

## Kernel / vendor

- Kernel: [android_kernel_huawei_hwjdn](https://github.com/Shaheddan/android_kernel_huawei_hwjdn)
  (branch `lineage-22.2`): the `lineage-21` kernel plus charge cycle counting
  in the vm-bms (`qcom,batt-aging-comp` in the L01 DTS, which the W09 and
  AL00 include) and `cycle_count` forwarded by the bq24296m charger driver.
- Vendor: [proprietary_vendor_huawei_hwjdn](https://github.com/Shaheddan/proprietary_vendor_huawei_hwjdn)
  (branch `lineage-22.2`) — extracted from Huawei's stock firmware (EMUI 4,
  Android 6.0.1), with the shims patched into the blobs; `rmt_storage` is
  kiwi's dynamically linked build, and the Adreno GL driver is crackling's
  V@145, as on kiwi.
- SELinux: [android_device_qcom_sepolicy-legacy](https://github.com/Shaheddan/android_device_qcom_sepolicy-legacy)
  (branch `lineage-22.2`, shared with kiwi).

## Credits

- LineageOS team (17.1 hwjdn tree, msm8916 platform work)
- acroreiser, whose LeEco Le 2 (s2) 3.10 kernel with eBPF/PSI backports is
  the source of this kernel's Android 13 backports, and whose s2 trees were
  kiwi's main reference for Android 14 and 15
- [TipzTeam](https://codeberg.org/TipzTeam) — `sepolicy-legacy`,
  msm8916-common and wt88047x trees
- The HTC One A9 (hiae) Android 13 tree, used as a boot reference for kiwi's
  port
- niclimcy's wt88047x trees and the cyanogen/Motorola msm8916-common trees,
  used as references in earlier versions of this port
- Huawei, for the JDN kernel source, and the JDN-W09 owner who shared it
  and reported the W09 bugs
