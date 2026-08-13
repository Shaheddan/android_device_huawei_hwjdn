# TWRP 3.7.0 device tree — Huawei MediaPad T2 8.0 Pro (JDN-L01)

TWRP 3.7.0 for the Huawei MediaPad T2 8.0 Pro / Honor Pad 2
(JDN-L01, codename `jordan`, `ro.product.device` = `hwjdn`, MSM8939v2).

Built on the TWRP 11 (Android 11) branch. Everything works: display,
touch, backlight and screen on/off, adb, MTP, and all partitions mount.

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

`/data` is full-disk encrypted, and `TW_INCLUDE_CRYPTO` is off, so internal
storage reads 0 MB. Install ROM zips from the microSD. Installing a custom
ROM formats `/data` anyway, which removes the encryption permanently.

## Building

    repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-11
    repo sync

Then place this tree at `device/huawei/hwjdn` and:

    export ALLOW_MISSING_DEPENDENCIES=true
    source build/envsetup.sh
    lunch twrp_hwjdn-eng
    mka recoveryimage

### One required manifest change

Android 11's `adbd` uses aio FunctionFS, which needs kernel 3.18 or newer.
On this device's 3.10 kernel adb enumerates but never completes the
handshake, leaving it permanently `offline`. Add
`.repo/local_manifests/twrp-syscore.xml`:

    <?xml version="1.0" encoding="UTF-8"?>
    <manifest>
      <remove-project name="android_system_core" />
      <project path="system/core" name="mohammadsa9/android_system_core"
               remote="github" revision="android-11" clone-depth="1" />
    </manifest>

then `repo sync --force-sync system/core`.

### If you change TW_THEME or the resolution

Delete `out/soong` as well as `out/target/product/hwjdn/recovery`. The theme
is installed by a Soong plugin that runs at analysis time, and a cached
result leaves `/twres` missing — the build still reports success, and TWRP
then crash-loops on "unable to load theme".

## Notes on this port

Huawei published neither kernel source nor a device tree for this model, so
most of it was recovered from the device and its stock firmware.

- **Boot header** — `pagesize` 2048, `ramdisk_offset` 0x01000000,
  `tags_offset` 0x00000100. Both offsets differ from the usual msm8939
  values; these are what the stock RECOVERY.img uses.
- **Separated DT** — Android 11's mkbootimg has no `--dt`, and `--dtb` is a
  header v2 field, which this 2016 bootloader cannot parse. The tree ships a
  legacy mkbootimg and overrides the image rule via `BOARD_CUSTOM_BOOTIMG_MK`.
- **Backlight** — sits on three GPIOs that no CAF property name covers, so
  `/sys/class/leds/lcd-backlight/brightness` accepted values and lit nothing
  until the kernel was taught to drive them.
- **Touch** — the DTS offers three digitisers; this unit has the Novatek. Its
  chip ID cannot be read, but it runs its own firmware and reports in the
  standard Novatek point format, so a minimal driver was written against the
  packets captured from the bus.

`tools/` holds the utilities written along the way: an UPDATE.APP splitter,
a QCDT reader and writer, the i2c probes used to identify the touch
controller, and the DTS fix-up.

## Kernel

https://github.com/Shaheddan/android_kernel_huawei_jdnl01

`prebuilt/Image` and `prebuilt/dt.img` are built from that source and are
included so this tree builds without a kernel build first.

## Credits

- **@mohammadsa9** — the kiwi (Honor 5X) kernel this port's kernel is based
  on, and the patched `system/core` that makes adb work on a 3.10 kernel.
  Neither this recovery nor the kernel would exist without that work.
- TeamWin, for TWRP.

## License

Apache-2.0, following AOSP device tree convention. Individual files retain
their own headers where present; the bundled `mkbootimg/mkbootimg.py` is
AOSP code under Apache-2.0. The kernel is GPLv2 and lives in its own repo.
