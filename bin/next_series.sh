#! /bin/bash

set -e

QEMU_SRCDIR="/home/claudio/git/qemu-pristine/qemu"
if test x`pwd` != "x${QEMU_SRCDIR}" ; then
    echo "call from the QEMU top source directory."
    exit 1
fi

SED="sed -E"

if test "x$1" = "x" ; then
    echo "Missing SERIES_NAME!"
    echo "Usage: next_series.sh SERIES_NAME starting_commitid [RFC]"
    exit 1
fi
if test "x$2" = "x"; then
    echo "Missing starting_commitid!"
    echo "Usage: next_series.sh SERIES_NAME starting_commitid [RFC]"
    exit 1
fi

SERIES=`echo "$1" | ${SED} 's,^(.+[^/])/+$,\1,'`
echo $SERIES

STARTING_COMMIT="$2"

if test "x$3" ="xRFC" ; then
    S_PREFIX=RFC
else
    S_PREFIX=PATCH
fi

COVER="${SERIES}/0000-cover-letter.patch"

V=`echo ${SERIES} | ${SED} 's,^.+_v([0-9]+)$,\1,'`

if test "x${V}" = "x${SERIES}" ; then
    V=""
    NEW_V=2
else
    NEW_V=`expr ${V} + 1`
fi

NEW_SERIES=`echo ${SERIES} | ${SED} 's,^(.*_v)([0-9]+)$,\1'${NEW_V}','`

if test "x${NEW_SERIES}" = "x${SERIES}" ; then
    NEW_SERIES=`echo ${SERIES}_v2`
fi

echo "old series version = $V"
echo "new series version = $NEW_V"

echo "old series directory = ${SERIES}"
echo "new series directory = ${NEW_SERIES}"

if test -f ${COVER} ; then
    echo "Found: ${COVER}"
else
    echo "Not Found: ${COVER}"
    exit 1
fi

if mkdir ${NEW_SERIES} ; then
    echo "Created: ${NEW_SERIES}"
else
    exit 1
fi

NEW_COVER="${NEW_SERIES}/0000-cover-letter.patch"

if test "x${V}" = "x" ; then
    REGEX='s,^Subject: \[(.*)\](.*)$,\1[\2 v2]\3,'
else
    REGEX='s,^Subject: \[(.*)v[0-9]*(.*)\](.*)$,[\1v'${NEW_V}'\2]\3,'
fi
SUBJECT=`grep "^Subject: " ${COVER} | ${SED} "${REGEX}"`
TO_LIST=`grep "^To: " ${COVER} | ${SED} 's,\$,\\\,'`
CC_LIST=`grep "^Cc: " ${COVER} | ${SED} 's,\$,\\\,' | head --bytes=-2`
TEXT=`cat ${COVER} | ${SED} -n '/^Subject: /,/^Claudio$/p' | tail --lines=+2 | ${SED} 's,\$,\\\,'`

git format-patch -q --cover-letter --subject-prefix="${S_PREFIX} v{$NEW_V}" ${STARTING_COMMIT}
mv *.patch ${NEW_SERIES}/

${SED} -i 's,^Subject: .*$,Subject: '"${SUBJECT}"',' ${NEW_COVER}

${SED} -i '/^\*\*\* BLURB HERE \*\*\*.*$/ a\
'"${TEXT}"'
' ${NEW_COVER}

for PATCH in `ls ${NEW_SERIES}/*.patch`; do

    ${SED} -i '/^From: .*$/ a\
'"${TO_LIST}"'
'"${CC_LIST}"'
' ${PATCH}

done
