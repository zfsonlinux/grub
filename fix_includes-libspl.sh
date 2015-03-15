#!/bin/bash

echo "include <sys/{param,time,types,sysmacros,string,strings,file}.h> -> sys/<file>_zfs.h"
rgrep -E 'sys/param.h|sys/time.h|sys/types.h|sys/sysmacros.h|sys/string.h|sys/strings.h|sys/file.h' \
    /usr/include/lib{spl,zfs} | sed 's@:.*@@' | sort | uniq | grep -v '~' | \
    while read file; do
	echo -n "  $file: "
	cat "$file" | \
	    sed -e 's@include <sys/param\.h@include <sys/param_zfs.h@' \
		-e 's@include <sys/time\.h@include <sys/time_zfs.h@' \
		-e 's@include <sys/types\.h@include <sys/types_zfs.h@' \
		-e 's@include <sys/sysmacros\.h@include <sys/sysmacros_zfs.h@' \
		-e 's@include <sys/string\.h@include <sys/string_zfs.h@' \
		-e 's@include <sys/strings\.h@include <sys/strings_zfs.h@' \
		-e 's@include <sys/file\.h@include <sys/file_zfs.h@' \
	    > "$file.new" && mv "$file.new" "$file"
	echo "done."
    done

echo
echo "include_next -> include"
rgrep -E 'sys/param_zfs.h|sys/time_zfs.h|sys/types_zfs.h|sys/sysmacros_zfs.h|sys/string_zfs.h|sys/strings_zfs.h|sys/file_zfs.h' \
    /usr/include/lib{spl,zfs} | grep include_next | sed 's@:.*@@' | sort | uniq | grep -v '~' | \
    while read file; do
	echo -n "  $file: "
	cat "$file" | \
	    sed -e 's@include_next @include @' | \
	    > "$file.new" && mv "$file.new" "$file"
	echo "done."
    done

echo
echo "/usr/include/lib{spl,zfs}/sys/{param,time,types,sysmacros,string,strings,file}.h -> /usr/include/lib{spl,zfs}/sys/<file>_zfs.h"
for file in param time types sysmacros string strings file; do
    echo -n "  $file.h"

    f=`find /usr/include/lib{spl,zfs} -name "$file.h" | grep -v /rpc/`
    new=`echo "$f" | sed 's@\.h@_zfs.h@'`
    mv "$f" "$new"
    echo "done."
done

echo
echo "misc"
echo -n "  assert.h"
cat /usr/include/libspl/assert.h | \
    sed -e 's@^#if defined(__STDC__)@#if defined(__STDC_VERSION__)@' \
	-e 's@^extern void __assert@// extern void __assert@' \
    > /usr/include/libspl/assert.h.new
mv /usr/include/libspl/assert.h.new /usr/include/libspl/assert.h
echo "done."

echo -n "  uio.h"
cat /usr/include/libspl/sys/uio.h | \
    sed 's@^#include_next <sys/uio.h>@#include <sys/types_zfs.h>\
#include_next <sys/uio.h>@' \
    > /usr/include/libspl/sys/uio.h.new
mv /usr/include/libspl/sys/uio.h.new /usr/include/libspl/sys/uio.h
echo "done."
