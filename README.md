# Device tree for Huawei MediaPad T2 8.0 Pro (hwjdn) — LineageOS 20

Unofficial LineageOS 20 (Android 13) for the Huawei MediaPad T2 8.0 Pro,
running on the tablet's 3.10 kernel with eBPF, PSI and cgroup v2 backported
so that Android 13 can boot and run on it. It builds on this tree's
LineageOS 19.1 port and on the Honor 5X (kiwi) LineageOS 20 port, which uses
the same SoC, the same kernel lineage and the same 3.10 backports.

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

**Working.** The first LineageOS 20 build (`hwjdn-lineage-20.0-20261022-0245`) runs on the
developer's JDN-L01 with no known issues. The W09 and AL00 have not been
tested yet; reports are welcome.

## Download

GitHub release [`hwjdn-lineage-20.0-20261022-0245`](https://github.com/Shaheddan/android_device_huawei_hwjdn/releases/tag/hwjdn-lineage-20.0-20261022-0245):

- `lineage-20.0-20261022-UNOFFICIAL-hwjdn.zip`
- SHA-256 `777b4abff98da589c50dd518af7bb8aef5a7ab7428247b31c30fbb0d03cb07de`

Flash it with TWRP: release [`hwjdn-twrp-20261018-0447`](https://github.com/Shaheddan/android_device_huawei_hwjdn/releases/tag/hwjdn-twrp-20261018-0447) carries the L01, W09 and
AL00 DTBs. Coming from Huawei's stock firmware, do a Factory Reset in TWRP
first.

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
  configurable level and holds there. A live status card shows what the
  charger and battery are doing. Backed by the BQ24296 charger IC's
  charge-disable path (`factory_diag` sysfs node). Normal charging always
  returns when the charger is unplugged.

## Building

`manifests/` adds this tree, the kernel (at `kernel/huawei/jdn`), the vendor
blobs, kiwi's device and vendor trees (hwjdn uses kiwi's `libwcnss_qmi`;
kiwi itself is not built), `device/qcom/sepolicy-legacy`, the msm8916 CAF
HALs and `dtbtool`.

    repo init -u https://github.com/LineageOS/android.git -b lineage-20.0 --git-lfs -g default,-pixel-extra
    mkdir -p .repo/local_manifests
    curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/lineage-20/manifests/hwjdn.xml -o .repo/local_manifests/hwjdn.xml
    curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/lineage-20/manifests/hwjdn-support.xml -o .repo/local_manifests/hwjdn-support.xml
    repo sync
    bash device/huawei/hwjdn/patches/apply-patches.sh
    source build/envsetup.sh
    lunch lineage_hwjdn-userdebug
    mka bacon

Build `userdebug`; the sepolicy tree only relaxes neverallows for
eng/userdebug.

### On crave.io

From a folder set up for Crave's LOS 20 project:

    repo init -u https://github.com/accupara/los20.git -b lineage-20.0 --git-lfs
    crave run --no-patch -- "curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/lineage-20/crave/build-hwjdn.sh | GH_TOKEN=<token> bash"

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
- **Stale commit-graph indexes.** The workspace is shared with the 19.1
  builds, and a commit-graph that names lost commits makes git refuse to
  fetch, so the resync fails; the script deletes them before the resync.

## Branches

| Branch | Contents |
| :----- | :------- |
| `main` | TWRP 3.7.0 device tree |
| `twrp-variants` | TWRP with the W09 and AL00 DTBs (works on the L01; W09/AL00 untested) |
| `lineage-19.1` | LineageOS 19.1 release |
| `jdn-pad-power` | LineageOS 19.1 with the Huawei JDN source work (works on the L01) |
| `lineage-20` | LineageOS 20 (this branch; works on the L01) |

## Kernel / vendor

- Kernel: [android_kernel_huawei_hwjdn](https://github.com/Shaheddan/android_kernel_huawei_hwjdn)
  (branch `lineage-20`)
- Vendor: [proprietary_vendor_huawei_hwjdn](https://github.com/Shaheddan/proprietary_vendor_huawei_hwjdn)
  (branch `lineage-20`) — extracted from Huawei's stock firmware (EMUI 4,
  Android 6.0.1); `rmt_storage` is kiwi's dynamically linked build, because
  the stock static one cannot read the properties of newer Android versions

## Credits

- LineageOS team (17.1 hwjdn tree, msm8916 platform work)
- acroreiser, whose LeEco Le 2 (s2) 3.10 kernel with eBPF/PSI backports is
  the source of this kernel's Android 13 backports
- [TipzTeam](https://codeberg.org/TipzTeam) — `sepolicy-legacy`,
  msm8916-common and wt88047x trees
- The HTC One A9 (hiae) Android 13 tree, used as a boot reference for kiwi's
  port
- niclimcy's wt88047x trees and the cyanogen/Motorola msm8916-common trees,
  used as references in earlier versions of this port
- Huawei, for the JDN kernel source, and the JDN-W09 owner who shared it
  and reported the W09 bugs
