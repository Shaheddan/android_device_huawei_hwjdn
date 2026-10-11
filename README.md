# TWRP 3.7.0 device tree — Huawei MediaPad T2 8.0 Pro (hwjdn)

TWRP 3.7.0 for the Huawei MediaPad T2 8.0 Pro / Honor Pad 2
(codename `jordan`, `ro.product.device` = `hwjdn`, MSM8939v2), built on the
TWRP 11 (Android 11) branch.

## Supported models

| Model | Board ID | Status |
| :---- | :------- | :----- |
| JDN-L01 (LTE) | `0x1f94` | Supported and tested |
| JDN-W09 (Wi-Fi) | `0x1f92` | `twrp-variants` branch — not yet tested on a W09 |
| JDN-AL00 (China, LTE) | `0x1fc2` | `twrp-variants` branch — not yet tested on an AL00 |

The bootloader only boots a recovery whose `dt.img` has a DTB with the
device's board ID. The first release carried only the L01's, so it could
not boot on a W09 or AL00. `prebuilt/dt.img` now carries one DTB per model,
built from the kernel's `huawei_jdn_l01.dts`, `huawei_jdn_w09.dts` and
`huawei_jdn_al00.dts`. The W09 and AL00 trees follow Huawei's own JDN source:
they include the L01's and change only the model, board ID, modem ID, the
missing SAR sensor, the variant name and the W09 panel's front porches.

## Device

| | |
| --- | --- |
| SoC | Qualcomm MSM8939v2, Snapdragon 616, 8× Cortex-A53 |
| GPU | Adreno 405 |
| Display | 8" IPS 1200×1920, INX_NT51021_8_1200P_VIDEO |
| Touch | Novatek (i2c-5, 0x01) |
| RAM / storage | 2 GB / 16 GB + microSD |
| Shipped with | Android 6.0.1, EMUI 4.0, kernel 3.10.49 |

## Status

| | |
| --- | --- |
| Display, correct resolution and orientation | working |
| Touch | working |
| Backlight, screen on/off | working |
| adb | working |
| MTP | working |
| All partitions mount | working |
| Backup / restore | working |
| `/data` decryption (FDE) | not implemented — see below |

Checked on the JDN-L01 with the first release's kernel. The prebuilt kernel
is now the one the LineageOS 19.1 `jdn-pad-power` build uses, and is being
re-checked in TWRP.

`/data` is full-disk encrypted, and `TW_INCLUDE_CRYPTO` is off, so internal
storage reads 0 MB. Install ROM zips from the microSD. Installing a custom
ROM formats `/data` anyway, which removes the encryption permanently.

## Building

`manifests/twrp-hwjdn.xml` adds this tree and swaps in mohammadsa9's
`system/core`. Android 11's `adbd` uses aio FunctionFS, which needs kernel
3.18 or newer; on this device's 3.10 kernel adb enumerates but never
completes the handshake and stays `offline`. mohammadsa9's `android-11`
branch brings back adbd's legacy USB path.

    repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-11
    mkdir -p .repo/local_manifests
    curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/twrp-variants/manifests/twrp-hwjdn.xml -o .repo/local_manifests/twrp-hwjdn.xml
    repo sync
    export ALLOW_MISSING_DEPENDENCIES=true
    source build/envsetup.sh
    lunch twrp_hwjdn-eng
    mka recoveryimage

### On crave.io

`crave/build-twrp.sh` runs the same steps on a Crave build node, from a
folder set up for Crave's TWRP project:

    repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-11 --git-lfs
    crave run --no-patch -- "curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/twrp-variants/crave/build-twrp.sh | bash"
    crave pull out/target/product/hwjdn/recovery.img

### If you change TW_THEME or the resolution

Delete `out/soong` as well as `out/target/product/hwjdn/recovery`. The theme
is installed by a Soong plugin that runs at analysis time, and a cached
result leaves `/twres` missing — the build still reports success, and TWRP
then crash-loops on "unable to load theme". The crave script checks for it.

## Notes on this port

When this port started, neither kernel source nor a device tree existed for
this model, so most of it was recovered from the device and its stock
firmware. Huawei's JDN kernel source surfaced later and is what the
`jdn-pad-power` kernel ports from.

- **Boot header** — `pagesize` 2048, `ramdisk_offset` 0x01000000,
  `tags_offset` 0x00000100. Both offsets differ from the usual msm8939
  values; these are what the stock RECOVERY.img uses.
- **Separated DT** — Android 11's mkbootimg has no `--dt`, and `--dtb` is a
  header v2 field, which this 2016 bootloader cannot parse. The tree ships a
  legacy mkbootimg and overrides the image rule via `BOARD_CUSTOM_BOOTIMG_MK`.
- **Backlight** — the panel is lit through three GPIOs no CAF property name
  covers and dimmed by a TI LM36923 at i2c-0 `0x36`. The first release only
  switched the GPIOs; the current kernel drives the LM36923 with Huawei's
  power sequence and brightness curve.
- **Touch** — the DTS offers three digitisers; this unit has the Novatek. Its
  chip ID cannot be read, but it runs its own firmware and reports in the
  standard Novatek point format, so a minimal driver was written against the
  packets captured from the bus.

`tools/` holds the i2c probes used to identify the touch controller
(`nvtid.c`, `nvtread.c`), the installer that generated this tree's first
revision, and the first backlight patch, now part of the kernel.

## Kernel

https://github.com/Shaheddan/android_kernel_huawei_hwjdn (`jdn-pad-power`)

`prebuilt/Image` and `prebuilt/dt.img` are built from that source and
included so this tree builds without a kernel build first.
`prebuilt/PREBUILT-INFO.txt` records the kernel commit, the dtbtool revision
and their checksums. `dt.img` is packed with LineageOS's dtbtool the same way
the LineageOS build packs the ROM's (`-2`, page size 2048), from the three
jdn DTBs only.

## Credits

- **@mohammadsa9** — the kiwi (Honor 5X) kernel this port's kernel is based
  on, and the patched `system/core` that makes adb work on a 3.10 kernel.
  Neither this recovery nor the kernel would exist without that work.
- Huawei, for the JDN kernel source, and the JDN-W09 owner who shared it.
- TeamWin, for TWRP.

## License

Apache-2.0, following AOSP device tree convention. Individual files retain
their own headers where present; the bundled `mkbootimg/mkbootimg.py` is
AOSP code under Apache-2.0. The kernel is GPLv2 and lives in its own repo.
