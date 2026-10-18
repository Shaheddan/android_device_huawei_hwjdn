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

# Crave keeps .repo between jobs, and LineageOS 19.1 and 20 share this workspace. Crave
# build 306322, the first LineageOS 20 job after the 19.1 ones, died in resync on
# LineageOS/android_device_qcom_sepolicy_vndr: "You are attempting to fetch ad27d810...,
# which is in the commit graph file but not in the object database". That store's
# commit-graph (an index git writes during fetch and gc) still lists commits whose objects
# are gone; git 2.55 refuses to fetch then, and resync.sh's retry deletes only the
# checkout, not the shared object store, so it fails the same way. A commit-graph is only
# an index: deleting it loses nothing, and the next fetch brings back whatever is really
# missing (reproduced with git 2.55: same error before, clean fetch after). The find skips
# the loose-object and pack directories so it stays quick.
if [ -d .repo ]; then
  HWJDN_CG=$(find .repo/project-objects .repo/projects \
      -path '*/objects/??' -prune -o -path '*/objects/pack' -prune -o \
      \( -name commit-graph -o -name commit-graphs \) -path '*/objects/info/*' -print 2>/dev/null)
  printf '%s\n' "$HWJDN_CG" | grep . | xargs -r rm -rf
  echo "hwjdn: removed $(printf '%s\n' "$HWJDN_CG" | grep -c .) commit-graph indexes under .repo"
  [ -z "$(find .repo/project-objects .repo/projects -path '*/objects/??' -prune -o -path '*/objects/pack' -prune -o \( -name commit-graph -o -name commit-graphs \) -path '*/objects/info/*' -print 2>/dev/null)" ] \
    || { echo "!! commit-graph indexes still present under .repo"; exit 1; }
fi
/opt/crave/resync.sh || { echo "!! resync failed"; exit 1; }
bash device/huawei/hwjdn/patches/apply-patches.sh lineage-20 || { echo "!! hwjdn patches failed"; exit 1; }

# LineageOS 19.1/20 run old host tools that need libncurses.so.5 and libtinfo.so.5:
#  - prebuilts/clang/host/linux-x86/clang-3289846 (clang.real, llvm-link, ...), which
#    compiles RenderScript's libclcore.bc (crave build 305623 stopped there at 14%);
#  - tools built in the tree against the glibc 2.17 sysroot's ncurses 5 through
#    libLLVM_android.so: bcc_strip_attr, which make runs from out/host/linux-x86/bin (crave
#    build 305713, 42%), and llvm-rs-cc, which 19.1's soong runs from
#    out/soong/host/linux-x86/bin for RenderScript sources such as libstagefright_mediafilter
#    (HostToolPath in android/config.go; crave build 305971, 21%). 20's soong runs it from
#    out/host/linux-x86/bin instead;
#  - the RenderScript tools in prebuilts/sdk/tools/linux (bcc_compat, llvm-rs-cc).
# Crave's Debian 13 image only has the .so.6 versions. The ncurses functions these tools
# import are unversioned, and the .so.6 libraries provide them, so .so.5 names pointing at
# the system's .so.6 are enough. Each of these trees keeps its tools in bin/ and their
# libraries in lib64/, which soong-built tools reach through RUNPATH $ORIGIN/../lib64, so
# the links go in each tree's lib64. LD_LIBRARY_PATH would not work: soong_ui hands ninja
# only an allowlist of environment variables and it is not on it. Soong's cleanups only
# delete files a module installed earlier, so links under out/ survive; they are made
# again on every run anyway.
RSCLANG=prebuilts/clang/host/linux-x86/clang-3289846
HWJDN_O=${OUT_DIR:-out}
HWJDN_NC5=0
for n in libncurses.so.5 libtinfo.so.5; do
  ls "/lib/x86_64-linux-gnu/$n" "/usr/lib/x86_64-linux-gnu/$n" "/lib64/$n" "/usr/lib64/$n" >/dev/null 2>&1 \
    || HWJDN_NC5=1
done
if [ "$HWJDN_NC5" = 1 ]; then
  TINFO6=$(ls /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /lib/x86_64-linux-gnu/libtinfo.so.6 2>/dev/null | head -1)
  NCURSES6=$(ls /usr/lib/x86_64-linux-gnu/libncurses.so.6 /lib/x86_64-linux-gnu/libncurses.so.6 2>/dev/null | head -1)
  [ -n "$TINFO6" ] || { echo "!! no libtinfo.so.6 on this host"; exit 1; }
  HWJDN_TREES="$RSCLANG prebuilts/sdk/tools/linux $HWJDN_O/host/linux-x86 $HWJDN_O/soong/host/linux-x86"
  HWJDN_DIRS=
  for t in $HWJDN_TREES; do
    # out/ trees may not exist yet on a fresh workspace; their tools are built later and
    # must find the links then. Source trees are only touched where they exist.
    case "$t" in
      "$HWJDN_O"/*) mkdir -p "$t/lib64" || { echo "!! cannot create $t/lib64"; exit 1; } ;;
      *) [ -d "$t/lib64" ] || continue ;;
    esac
    ln -sfn "$TINFO6" "$t/lib64/libtinfo.so.5"
    ln -sfn "${NCURSES6:-$TINFO6}" "$t/lib64/libncurses.so.5"
    HWJDN_DIRS="$HWJDN_DIRS $t/lib64"
  done
  echo "hwjdn: libncurses.so.5 -> ${NCURSES6:-$TINFO6}, libtinfo.so.5 -> $TINFO6 in:$HWJDN_DIRS"
  # Check every tool already on disk in those trees (out/ ones exist only when the
  # workspace kept an earlier build). One that still misses a name is fatal now rather than
  # 20 minutes into the build, except in prebuilts/sdk, which a platform build may never
  # run: that one is reported with its dynamic section, so the log has the data to fix it.
  HWJDN_BAD=; HWJDN_WARN=; HWJDN_N=0
  for t in $HWJDN_TREES; do
    for f in "$t"/bin/*; do
      [ -f "$f" ] && [ -x "$f" ] || continue
      HWJDN_N=$((HWJDN_N + 1))
      l=$(ldd "$f" 2>/dev/null) || true
      case "$l" in
        *"libncurses.so.5 => not found"*|*"libtinfo.so.5 => not found"*)
          echo "hwjdn: $f still misses ncurses 5; NEEDED/RUNPATH:"
          readelf -d "$f" 2>&1 | grep -E 'NEEDED|RPATH|RUNPATH|readelf' | sed 's/^/hwjdn:   /'
          case "$f" in prebuilts/sdk/*) HWJDN_WARN="$HWJDN_WARN $f" ;; *) HWJDN_BAD="$HWJDN_BAD $f" ;; esac ;;
      esac
    done
  done
  [ -z "$HWJDN_WARN" ] || echo "hwjdn: WARNING, still no libncurses.so.5/libtinfo.so.5 for:$HWJDN_WARN"
  [ -z "$HWJDN_BAD" ] || { echo "!! still no libncurses.so.5/libtinfo.so.5 for:$HWJDN_BAD"; exit 1; }
  if [ -x "$RSCLANG/bin/clang.real" ]; then
    "$RSCLANG/bin/clang.real" --version >/dev/null 2>&1 \
      || { echo "!! $RSCLANG still cannot start:"; "$RSCLANG/bin/clang.real" --version; exit 1; }
  fi
  echo "hwjdn: checked $HWJDN_N host tools in:$HWJDN_DIRS (bin/ beside each)"
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
  ZIP=$(ls -t out/target/product/hwjdn/lineage-20.0-*-hwjdn.zip 2>/dev/null | head -1)
  [ -n "$ZIP" ] || { echo "!! no lineage-20.0 zip in out/target/product/hwjdn"; exit 1; }
  BRANCH=lineage-20 bash device/huawei/hwjdn/crave/upload-github.sh hwjdn-lineage-20.0 "$ZIP" \
    || { echo "!! upload failed"; exit 1; }
fi
