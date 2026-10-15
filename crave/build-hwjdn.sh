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

# LineageOS 19.1/20 run old host tools that need libncurses.so.5 and libtinfo.so.5:
#  - prebuilts/clang/host/linux-x86/clang-3289846 (clang.real, llvm-link, ...), which
#    compiles RenderScript's libclcore.bc (crave build 305623 stopped there at 14%);
#  - host tools built in the tree against the glibc 2.17 sysroot's ncurses 5, such as
#    bcc_strip_attr through libLLVM_android.so (crave build 305713 stopped there at 42%).
# Crave's Debian 13 image only has the .so.6 versions. The ncurses functions these tools
# import are unversioned, and the .so.6 libraries provide them, so .so.5 names pointing at
# the system's .so.6 are enough. The links must sit in a directory each tool's RUNPATH
# ($ORIGIN/../lib64) searches: soong_ui hands ninja only an allowlist of environment
# variables and LD_LIBRARY_PATH is not on it, so exporting it here would never reach the
# build. Soong's cleanups only delete files a module installed earlier, so links in
# out/host/linux-x86/lib64 survive; they are made again on every run anyway.
RSCLANG=prebuilts/clang/host/linux-x86/clang-3289846
HWJDN_HOSTLIB=${OUT_DIR:-out}/host/linux-x86/lib64
HWJDN_NC5=0
for n in libncurses.so.5 libtinfo.so.5; do
  ls "/lib/x86_64-linux-gnu/$n" "/usr/lib/x86_64-linux-gnu/$n" "/lib64/$n" "/usr/lib64/$n" >/dev/null 2>&1 \
    || HWJDN_NC5=1
done
if [ "$HWJDN_NC5" = 1 ]; then
  TINFO6=$(ls /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /lib/x86_64-linux-gnu/libtinfo.so.6 2>/dev/null | head -1)
  NCURSES6=$(ls /usr/lib/x86_64-linux-gnu/libncurses.so.6 /lib/x86_64-linux-gnu/libncurses.so.6 2>/dev/null | head -1)
  [ -n "$TINFO6" ] || { echo "!! no libtinfo.so.6 on this host"; exit 1; }
  HWJDN_DIRS="$HWJDN_HOSTLIB"
  [ -d "$RSCLANG/lib64" ] && HWJDN_DIRS="$RSCLANG/lib64 $HWJDN_DIRS"
  for d in $HWJDN_DIRS; do
    mkdir -p "$d" || { echo "!! cannot create $d"; exit 1; }
    ln -sfn "$TINFO6" "$d/libtinfo.so.5"
    ln -sfn "${NCURSES6:-$TINFO6}" "$d/libncurses.so.5"
  done
  echo "hwjdn: libncurses.so.5 -> ${NCURSES6:-$TINFO6}, libtinfo.so.5 -> $TINFO6 in: $HWJDN_DIRS"
  # Check every tool already on disk that the build runs from these trees (out/host only
  # exists when the workspace kept an earlier build). A missing name there is fatal now
  # rather than an hour into the build; one in prebuilts/sdk is only reported, as data.
  HWJDN_BAD=; HWJDN_WARN=; HWJDN_N=0
  for f in "$RSCLANG"/bin/* "${OUT_DIR:-out}"/host/linux-x86/bin/* prebuilts/sdk/tools/linux/bin/*; do
    [ -f "$f" ] && [ -x "$f" ] || continue
    HWJDN_N=$((HWJDN_N + 1))
    l=$(ldd "$f" 2>/dev/null) || true
    case "$l" in
      *"libncurses.so.5 => not found"*|*"libtinfo.so.5 => not found"*)
        case "$f" in prebuilts/sdk/*) HWJDN_WARN="$HWJDN_WARN $f" ;; *) HWJDN_BAD="$HWJDN_BAD $f" ;; esac ;;
    esac
  done
  [ -z "$HWJDN_WARN" ] || echo "hwjdn: WARNING, still no libncurses.so.5/libtinfo.so.5 for:$HWJDN_WARN"
  [ -z "$HWJDN_BAD" ] || { echo "!! still no libncurses.so.5/libtinfo.so.5 for:$HWJDN_BAD"; exit 1; }
  if [ -x "$RSCLANG/bin/clang.real" ]; then
    "$RSCLANG/bin/clang.real" --version >/dev/null 2>&1 \
      || { echo "!! $RSCLANG still cannot start:"; "$RSCLANG/bin/clang.real" --version; exit 1; }
  fi
  echo "hwjdn: checked $HWJDN_N host tools; all in $RSCLANG and out/host load libncurses.so.5/libtinfo.so.5"
fi

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
