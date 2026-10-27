# Device tree for Huawei MediaPad T2 8.0 Pro (hwjdn) — LineageOS 21

Unofficial LineageOS 21 (Android 14) for the Huawei MediaPad T2 8.0 Pro,
running on the tablet's 3.10 kernel with eBPF, PSI and cgroup v2 backported.
It is this tree's LineageOS 20 port plus everything the Honor 5X (kiwi)
LineageOS 21 port needed to run Android 14 on the same SoC, the same kernel
lineage and the same Adreno 405 blobs.

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
one per model from Huawei's own JDN source: the W09 and AL00 trees include
the L01's and override only what Huawei's differ in (model, board ID, modem
ID, no SAR sensor, the variant name in the identity nodes, and the W09
panel's front porches). `init` reads the variant name back from
`/proc/app_info` and sets the model. The installer checks that TrustZone is
`TZ.BF.3.0.C3-00025`, the version on the L01; if a W09 or AL00 refuses the
zip on that check, please report it.

## Status

**In bring-up.** The first LineageOS 21 build has not been flashed yet;
what works will be listed here once it is tested on the tablet.

- The sensors HAL runs permissive in this first build (see *Android 14
  changes*); the rest of the device is SELinux enforcing.

For a daily driver, use LineageOS 20: branch `lineage-20`, release
[`hwjdn-lineage-20.0-20261022-0245`](https://github.com/Shaheddan/android_device_huawei_hwjdn/releases/tag/hwjdn-lineage-20.0-20261022-0245),
flashed with TWRP
[`hwjdn-twrp-20261018-0447`](https://github.com/Shaheddan/android_device_huawei_hwjdn/releases/tag/hwjdn-twrp-20261018-0447).

## Android 14 changes

Everything here comes from kiwi's LineageOS 21 port, which runs fully SELinux
enforcing on the same hardware.

### Kernel

The `lineage-21` kernel branch is the `lineage-20` kernel plus kiwi's
Android 14 kernel fixes: `renameat2` (flags 0 and `RENAME_NOREPLACE`, used by
Android 14's bionic `rename()` and the BPF loader), per-file SELinux labels
on bpffs (ClatCoordinator aborted without them), the FunctionFS AIO cancel
fix that ended the `adb root` hang on userdebug, and the gcc wrapper keeping
compiler diagnostics on stderr.

### Device tree

- First boot: no `ro.vndk.version` (linkerconfig aborted without a VNDK
  APEX), `ro.hardware.egl=adreno` (libEGL no longer scans), uncompressed
  APEXes (the 3.10 dm-verity rejects the decompressed-APEX table).
- SurfaceFlinger: shader-cache priming off (Adreno 405 cannot make an FP16
  EGLImage); gralloc and libmemalloc labelled same-process HALs.
- Bluetooth: zygote no longer preloads the GL driver, which clobbers x18, the
  shadow call stack register.
- ART: full dexpreopt and the release ART runtime on every variant
  (a build/make patch adds the opt-out).
- HALs: the sensors HAL binderized (Android 14 cannot load it into
  system_server); LineageOS' IRadio 1.4 wrapper in front of the stock rild's
  IRadio 1.1; the AIDL Wi-Fi HAL, which starts pronto; AIDL ClearKey and
  USB 1.3; no Trust HAL.
- Wi-Fi: `pmf=0`, since the pronto driver rejects associations that offer
  management frame protection.
- Battery: `vm_bms` starts at late-fs, so the percentage is right on the
  first boot after a flash.
- VINTF: target FCM level 5 and a device framework matrix for the legacy
  HIDL HALs.
- Build rules: Android 14 enforces vendor link types and header libraries,
  so the camera HAL compiles `CameraParameters` itself and the vendor modules
  request their headers; JdnDoze moves to `Android.bp`.
- SELinux: kiwi's enforcing harvest (bypass node label, bootanim, GNSS,
  mm-pp-daemon, vendor_init) and its dontaudits. The sensors HAL runs
  permissive for the first build only: which sysfs files the tablet's
  sensors blob opens has never been recorded, and the denials from that
  boot will give the exact rules.
- JdnParts: kiwi's Android 14 Material You redesign, with an animated
  battery that shows where the current flows.

### Platform patches

`patches/lineage-21/` (34 patches), applied by `patches/apply-patches.sh` —
kiwi's Android 14 set without its core-parking power patch (this tree parks
cores through `TARGET_POWERHAL_SET_INTERACTIVE_EXT`):

- **frameworks/av, frameworks/base**: camera HALv1 on Android 14's camera
  service
- **frameworks/opt/telephony**: SIM activation for the legacy Qualcomm RIL
- **packages/modules/Wifi**: ignore WPA3 transition-disable without SAE
- **build/make**: opt-out of the debug ART runtime
- **hardware/qcom-caf/msm8916 (audio, display, media), hardware/qcom-caf/common,
  hardware/lineage/interfaces, hardware/interfaces**: Android 14 build fixes
  for the msm8916 HALs and the legacy camera HAL
- **vendor/qcom/opensource/power**: msm8916 support
- **system/core, system/bpf, external/icu, vendor/lineage,
  device/lineage/sepolicy**: adaptations for the 3.10 kernel and this
  hardware

## Android 13 changes

### Kernel

The `lineage-20` kernel branch is kiwi's `lineage-20-ebpf` kernel with this
tablet's own commits on top: acroreiser's LeEco Le 2 (s2) 3.10 series
(kernfs and cgroup v2, eBPF, PSI, memcg, percpu-refcount), the arm64 `bpf()`
syscall, pidfd, FunctionFS AIO (adbd on Android 13), `IFA_FLAGS` netlink
(Wi-Fi IP provisioning), a 4.9 kernel version reported to the BPF users only,
and a fix so SELinux labels the cgroup2 inodes used in migration checks.

### Device tree

- Bluetooth: audio HAL entry in the manifest, profiles enabled through
  properties, APCF extended features disabled (the WCNSS firmware answers
  that command with a malformed reply), `libshim_btaddr_hwjdn` for
  `set_sched_policy` (moved to libprocessgroup).
- Camera: the legacy provider as a binderized service; cameraserver is built
  32-bit to match the 32-bit HALv1 (platform patch).
- `mm-pp-daemon` (display post-processing): an `IPowerManager` shim for its
  5.1-era library, and the unused partial-update node hidden from it to stop
  a busy loop.
- Packages Android 13 no longer has removed; FDE `encryptable` dropped from
  fstab; CellBroadcast privapp allowlists; full dexpreopt.
- SELinux: eMMC queue label, vendor property triggers Android 13 discards
  removed, Android 13 block types.
- `ro.kernel.ebpf.supported=false` removed: the kernel has eBPF now.
- JdnParts redesigned in Android 13's Material You style.

### Platform patches

`patches/lineage-20/` (one folder per repository), applied by
`patches/apply-patches.sh` — kiwi's Android 13 set:

- **frameworks/av, frameworks/base**: camera HALv1 (Camera1 API and the
  legacy Camera2 shim), video recording from HALv1 cameras
- **frameworks/opt/telephony**: SIM activation for the legacy Qualcomm RIL
- **packages/modules/Wifi**: ignore WPA3 transition-disable without SAE
- **frameworks/base (HWUI)**: fix for a 4-second UI freeze
- **system/core, system/bpf, system/netd, packages/modules/Connectivity,
  frameworks/native, hardware/…, vendor/…, device/lineage/sepolicy**:
  adaptations for the 3.10 kernel and this hardware

kiwi's core-parking patch for the power HAL is left out: this tree does the
same through `TARGET_POWERHAL_SET_INTERACTIVE_EXT`
(`power/power-interactive-ext.c`).

## Ported from Huawei's JDN source

Everything from the `jdn-pad-power` 19.1 work is in this branch:

| Change | Why | Tested on 19.1 |
| :----- | :-- | :----- |
| Huawei's pad panel power sequence (kernel) | The image woke up shifted a few rows after sleep, on the W09 and the L01. | L01: 6/6 wakes, no shift |
| All CPU cores online while the screen is on | `core_ctl` parked most cores and confined system_server, SurfaceFlinger, SystemUI and the launcher to two of them, so most apps lagged. The power HAL's screen on/off hook now sets `min_cpus` 4/4 with the screen on and the stock 0/1 with it off. | L01, at runtime |
| CFQ as the default I/O scheduler (kernel) | The tablet ran noop: `sys.io.scheduler` does nothing on 19.1. CFQ is the only scheduler here that honours the I/O priorities Android gives background work. | L01, at runtime |
| Touch controller interrupt instead of polling (kernel) | Polling every 15 ms added up to 15 ms of latency plus jitter. | L01, at runtime |
| Wall-charger input limit 1000 → 2000 mA (kernel DT) | With Huawei's own 2 A charger the battery got about 0.4 A with the screen on. | Not yet tested |
| HI843 O-Film camera OTP calibration (kernel) | The camera HAL found no white-balance calibration for the rear module; it lives in sensor OTP, which our kernel never read. | Not yet tested |
| `IP_MULTICAST` and `PM_WAKELOCKS_GC` (kernel) | Huawei's defconfig enables both; multicast is needed for mDNS, Cast and DLNA discovery. | Not yet tested |
| JDN-W09 and JDN-AL00 support (kernel + `init`) | See *Supported models*. | Needs W09/AL00 owners |
| DSI command-injection sysfs removed (kernel) | A root-writable bring-up tool that shipped in the 19.1 release. | — |


## Extras

- **Bypass charging** (JdnParts): Settings → Battery → Bypass charging.
  "Bypass now" holds the current battery level; "Auto bypass" charges to a
  configurable level and holds there. The page follows Android 14's Material
  You style: a status card with an animated battery that shows whether the
  current goes into the battery or around it, a status chip, and the
  auto-bypass level as its own row. Backed by the BQ24296 charger IC's
  charge-disable path (`factory_diag` sysfs node). Normal charging always
  returns when the charger is unplugged.

## Building

`manifests/` adds this tree, the kernel (at `kernel/huawei/jdn`), the vendor
blobs, kiwi's device and vendor trees (hwjdn uses kiwi's `libwcnss_qmi`;
kiwi itself is not built), `device/qcom/sepolicy-legacy`, the msm8916 CAF
HALs and `dtbtool`.

    repo init -u https://github.com/LineageOS/android.git -b lineage-21.0 --git-lfs -g default,-pixel-extra
    mkdir -p .repo/local_manifests
    curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/lineage-21/manifests/hwjdn.xml -o .repo/local_manifests/hwjdn.xml
    curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/lineage-21/manifests/hwjdn-support.xml -o .repo/local_manifests/hwjdn-support.xml
    repo sync
    bash device/huawei/hwjdn/patches/apply-patches.sh
    source build/envsetup.sh
    lunch lineage_hwjdn-ap2a-userdebug
    mka bacon

Build `userdebug`; the sepolicy tree only relaxes neverallows for
eng/userdebug.

### On crave.io

Crave has no LineageOS 21 project. From a folder set up for Crave's LOS 20
project, the script re-initialises that workspace to Crave's LineageOS 21
manifest (`accupara/los21`, the same commit as LineageOS's lineage-21.0),
as kiwi's LineageOS 21 builds do:

    repo init -u https://github.com/accupara/los20.git -b lineage-20.0 --git-lfs
    crave run --no-patch -- "curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/lineage-21/crave/build-hwjdn.sh | GH_TOKEN=<token> bash"

With `GH_TOKEN` set (a fine-grained token with Contents read/write on this
repository), the script uploads the zip to a GitHub pre-release before Crave
clears `out/`. It also works around Crave's Debian 13 build image:

- **ncurses 5.** RenderScript's old `clang-3289846`, `bcc_strip_attr`,
  `llvm-rs-cc` and the `prebuilts/sdk` tools need `libncurses.so.5` and
  `libtinfo.so.5`, which Debian 13 no longer ships. Their imports are
  unversioned, so the script links the `.so.5` names to the system's `.so.6`
  in the `lib64` of each host-tool tree, then checks every tool with `ldd`.
  It does this after `m nothing`, because the start of a build can run clean
  steps that delete `out/host` and `out/soong/host`.
- **gcc wrappers.** Crave renames compilers to `mbt-bin-<name>`; LineageOS's
  gcc 4.9 wrapper then looks for `real-mbt-bin-<name>`, so the script links
  those names to the real binaries.
- **Stale commit-graph indexes.** The workspace is shared with the 19.1 and
  20 builds, and a commit-graph that names lost commits makes git refuse to
  fetch, so the resync fails; the script deletes them before the resync.

## Branches

| Branch | Contents |
| :----- | :------- |
| `main` | TWRP 3.7.0 device tree |
| `twrp-variants` | TWRP with the W09 and AL00 DTBs (works on the L01; W09/AL00 untested) |
| `lineage-19.1` | LineageOS 19.1 release |
| `jdn-pad-power` | LineageOS 19.1 with the Huawei JDN source work (works on the L01) |
| `lineage-20` | LineageOS 20 (works on the L01) |
| `lineage-21` | LineageOS 21 (this branch, in bring-up) |

## Kernel / vendor

- Kernel: [android_kernel_huawei_hwjdn](https://github.com/Shaheddan/android_kernel_huawei_hwjdn)
  (branch `lineage-21`)
- Vendor: [proprietary_vendor_huawei_hwjdn](https://github.com/Shaheddan/proprietary_vendor_huawei_hwjdn)
  (branch `lineage-21`) — extracted from Huawei's stock firmware (EMUI 4,
  Android 6.0.1); `rmt_storage` is kiwi's dynamically linked build, because
  the stock static one cannot read the properties of newer Android versions

## Credits

- LineageOS team (17.1 hwjdn tree, msm8916 platform work)
- acroreiser, whose LeEco Le 2 (s2) 3.10 kernel with eBPF/PSI backports is
  the source of this kernel's Android 13 backports, and whose s2 LineageOS 21
  tree was kiwi's main Android 14 reference
- [TipzTeam](https://codeberg.org/TipzTeam) — `sepolicy-legacy`,
  msm8916-common and wt88047x trees
- The HTC One A9 (hiae) Android 13 tree, used as a boot reference for kiwi's
  port
- niclimcy's wt88047x trees and the cyanogen/Motorola msm8916-common trees,
  used as references in earlier versions of this port
- Huawei, for the JDN kernel source, and the JDN-W09 owner who shared it
  and reported the W09 bugs
