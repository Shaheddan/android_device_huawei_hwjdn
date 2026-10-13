#!/bin/bash
# Build TWRP 3.7 (twrp-11) for hwjdn (Huawei MediaPad T2 8.0 Pro) on a Crave build node.
# Start it from a local folder set up for Crave's TWRP project:
#   repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-11 --git-lfs
#   crave run --no-patch -- "curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/twrp-variants/crave/build-twrp.sh | bash"
# WHY each step:
#  - re-initialised to twrp-11 explicitly: the workspace may hold another TWRP
#    branch, and this tree is for Android 11 (twrp-12.1's bionic assumes more
#    of the kernel than this 3.10 provides);
#  - manifest fetched fresh, so the node builds exactly what is on GitHub;
#  - /opt/crave/resync.sh instead of repo sync: Crave's rule, it manages their cache;
#  - ALLOW_MISSING_DEPENDENCIES: the minimal TWRP manifest leaves out modules
#    that some makefiles name;
#  - the theme check at the end: TWRP's theme is copied into the ramdisk by a
#    Soong plugin at analysis time; a cached analysis can leave /twres empty
#    while the build reports success, and that recovery crash-loops.
# No `set -e`: build/envsetup.sh is not written for it; critical steps fail explicitly.
RAW=https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/twrp-variants
OUT=out/target/product/hwjdn

repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-11 --git-lfs \
  || { echo "!! repo init failed"; exit 1; }

rm -rf .repo/local_manifests && mkdir -p .repo/local_manifests || exit 1
curl -sfL "$RAW/manifests/twrp-hwjdn.xml" -o .repo/local_manifests/twrp-hwjdn.xml \
  || { echo "!! could not fetch twrp-hwjdn.xml"; exit 1; }

/opt/crave/resync.sh || { echo "!! resync failed"; exit 1; }

export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
lunch twrp_hwjdn-eng || { echo "!! lunch failed"; exit 1; }
mka recoveryimage || { echo "!! build failed"; exit 1; }

for f in splash.xml ui.xml; do
  [ -f "$OUT/recovery/root/twres/$f" ] \
    || { echo "!! TWRP theme missing from the ramdisk ($f): this recovery would crash-loop"; exit 1; }
done
ls -la "$OUT/recovery.img"
echo "TWRP for hwjdn built."
# With GH_TOKEN set, upload the image to a GitHub pre-release before Crave clears out/.
if [ -n "${GH_TOKEN:-}" ]; then
  IMG=/tmp/twrp-3.7-hwjdn-$(date -u +%Y%m%d).img
  cp "$OUT/recovery.img" "$IMG" || { echo "!! could not copy recovery.img"; exit 1; }
  BRANCH=twrp-variants bash device/huawei/hwjdn/crave/upload-github.sh hwjdn-twrp "$IMG" \
    || { echo "!! upload failed"; exit 1; }
fi
