#!/bin/bash
# Build LineageOS 20 for hwjdn (Huawei MediaPad T2 8.0 Pro) on a Crave build node.
# Start it from a local folder set up for Crave's LOS 20 project:
#   repo init -u https://github.com/accupara/los20.git -b lineage-20.0 --git-lfs
#   crave run --no-patch -- "curl -sfL https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/lineage-20/crave/build-hwjdn.sh | bash"
# WHY each step:
#  - LineageOS's own lineage-20.0 manifest (accupara/los20 points at the same
#    commit); -pixel-extra keeps the Pixel/Tensor repos out, as kiwi's tree did;
#  - manifests fetched fresh, so the node builds exactly what is on GitHub;
#  - /opt/crave/resync.sh instead of repo sync: Crave's rule, it manages their cache;
#  - patches applied AFTER the resync, because a resync resets the platform repos;
#  - userdebug by default: sepolicy-legacy relaxes its neverallows only for
#    eng/userdebug, and kiwi's LineageOS 20 runs as userdebug.
# No `set -e`: build/envsetup.sh is not written for it; critical steps fail explicitly.
VARIANT=${VARIANT:-userdebug}
RAW=https://raw.githubusercontent.com/Shaheddan/android_device_huawei_hwjdn/lineage-20

repo init -u https://github.com/LineageOS/android.git -b lineage-20.0 --git-lfs -g default,-pixel-extra \
  || { echo "!! repo init failed"; exit 1; }

rm -rf .repo/local_manifests && mkdir -p .repo/local_manifests || exit 1
for m in hwjdn.xml hwjdn-support.xml; do
  curl -sfL "$RAW/manifests/$m" -o ".repo/local_manifests/$m" || { echo "!! could not fetch $m"; exit 1; }
done

/opt/crave/resync.sh || { echo "!! resync failed"; exit 1; }
bash device/huawei/hwjdn/patches/apply-patches.sh lineage-20 || { echo "!! hwjdn patches failed"; exit 1; }

source build/envsetup.sh
lunch "lineage_hwjdn-$VARIANT" || { echo "!! lunch failed"; exit 1; }
mka bacon
