#!/bin/bash
# Build LineageOS 19.1 for hwjdn (Huawei MediaPad T2 8.0 Pro) on a Crave build node.
# Start it from a local folder set up for Crave's LOS 20 project:
#   repo init -u https://github.com/accupara/los20.git -b lineage-20.0 --git-lfs
#   crave run --no-patch -- "curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/jdn-pad-power/crave/build-hwjdn.sh | bash"
# WHY each step:
#  - Crave has no LineageOS 19.1 project: the job runs in the LOS 20 workspace
#    (project 36) and is re-initialised to LineageOS's own 19.1 manifest. Not
#    the lineage-19.1 branch of accupara/los20: that is an older snapshot
#    (five external/ projects still come from AOSP), while the patch set was
#    exported from a tree synced to LineageOS's manifest;
#  - manifests fetched fresh, so the node builds exactly what is on GitHub;
#  - /opt/crave/resync.sh instead of repo sync: Crave's rule, it manages their cache;
#  - patches applied AFTER the resync, because a resync resets the platform repos;
#  - userdebug by default: the 19.1 release is userdebug, and sepolicy-legacy
#    relaxes its neverallows only for eng/userdebug.
# No `set -e`: build/envsetup.sh is not written for it; critical steps fail explicitly.
VARIANT=${VARIANT:-userdebug}
RAW=https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/jdn-pad-power

repo init -u https://github.com/LineageOS/android.git -b lineage-19.1 --git-lfs \
  || { echo "!! repo init failed"; exit 1; }

rm -rf .repo/local_manifests && mkdir -p .repo/local_manifests || exit 1
for m in hwjdn.xml hwjdn-support.xml; do
  curl -sfL "$RAW/manifests/$m" -o ".repo/local_manifests/$m" || { echo "!! could not fetch $m"; exit 1; }
done

/opt/crave/resync.sh || { echo "!! resync failed"; exit 1; }
bash device/huawei/hwjdn/patches/apply-patches.sh lineage-19.1 || { echo "!! hwjdn patches failed"; exit 1; }

# Crave wraps compilers by renaming each one to mbt-bin-<name> (seen on kiwi's LineageOS 21
# builds). LineageOS's gcc-4.9 "gcc" is itself a python wrapper that execs real-<its own file
# name>, so after the rename it looks for real-mbt-bin-<name> and the kernel build dies. Point
# those names at the real binaries; harmless where nothing was renamed.
for t in aarch64/aarch64-linux-android-4.9:aarch64-linux-android arm/arm-linux-androideabi-4.9:arm-linux-androideabi; do
  d=prebuilts/gcc/linux-x86/${t%%:*}/bin
  p=${t##*:}
  for c in gcc g++; do
    [ -e "$d/real-$p-$c" ] && ln -sfn "real-$p-$c" "$d/real-mbt-bin-$p-$c"
  done
  echo "hwjdn: toolchain wrappers in $d:"
  ls -la "$d" | grep -E "mbt-bin|real-|$p-gcc\$|androidkernel-gcc" | sed 's/^/hwjdn:   /'
done

source build/envsetup.sh
lunch "lineage_hwjdn-$VARIANT" || { echo "!! lunch failed"; exit 1; }
mka bacon || { echo "!! build failed"; exit 1; }
# With GH_TOKEN set, upload the zip to a GitHub pre-release before Crave clears out/.
if [ -n "${GH_TOKEN:-}" ]; then
  ZIP=$(ls -t out/target/product/hwjdn/lineage-19.1-*-hwjdn.zip 2>/dev/null | head -1)
  [ -n "$ZIP" ] || { echo "!! no lineage-19.1 zip in out/target/product/hwjdn"; exit 1; }
  BRANCH=jdn-pad-power bash device/huawei/hwjdn/crave/upload-github.sh hwjdn-lineage-19.1 "$ZIP" \
    || { echo "!! upload failed"; exit 1; }
fi
