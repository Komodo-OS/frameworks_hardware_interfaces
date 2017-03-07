#!/bin/bash

#TODO(b/35916648) : Cleanup script to have a common implementation

if [ ! -d frameworks/hardware/interfaces ] ; then
  echo "Where is frameworks/hardware/interfaces?";
  exit 1;
fi

if [ ! -d system/libhidl/transport ] ; then
  echo "Where is system/libhidl/transport?";
  exit 1;
fi

packages=$(pushd frameworks/hardware/interfaces > /dev/null; \
           find . -type f -name \*.hal -exec dirname {} \; | sort -u | \
           cut -c3- | \
           awk -F'/' \
                '{printf("android.frameworks"); for(i=1;i<NF;i++){printf(".%s", $i);}; printf("@%s\n", $NF);}'; \
           popd > /dev/null)

package_roots="-r android.hidl:system/libhidl/transport \
               -r android.frameworks:frameworks/hardware/interfaces \
               -r android.hardware:hardware/interfaces"

for p in $packages; do
  echo "Updating $p";
  hidl-gen -Lmakefile ${package_roots} $p;
  rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  hidl-gen -Landroidbp ${package_roots} $p;
  rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
done

# subdirectories of frameworks/hardware/interfaces which contain an Android.bp file
android_dirs=$(find frameworks/hardware/interfaces/*/     \
              -name "Android.bp"               \
              -printf "%h\n"                   \
              | cut -d "/" -f1-3               \
              | sort | uniq)

echo "Updating Android.bp files."

for bp_dir in $android_dirs; do
  bp="$bp_dir/Android.bp"
  # locations of Android.bp files in specific subdirectory of frameworks/hardware/interfaces
  android_bps=$(find $bp_dir                   \
                -name "Android.bp"             \
                ! -path $bp_dir/Android.bp     \
                -printf "%h\n"                 \
                | sort)

  echo "// This is an autogenerated file, do not edit." > "$bp";
  echo "subdirs = [" >> "$bp";
  for a in $android_bps; do
    echo "    \"${a#$bp_dir/}\"," >> "$bp";
  done
  echo "]" >> "$bp";
done
