#! /bin/bash

set -e

QEMU_SRCDIR="/home/claudio/git/qemu-pristine/qemu"
if test x`pwd` != "x${QEMU_SRCDIR}" ; then
    echo "call from the QEMU top source directory."
    exit 1
fi

SED="sed -E"

if test "x$1" = "x" ; then
    echo "Missing SERIES_DIRNAME!"
    echo "Usage: new_series.sh SERIES_DIRNAME starting_commitid [RFC]"
    exit 1
fi
if test "x$2" = "x" ; then
    echo "Missing starting_commitid!"
    echo "Usage: new_series.sh SERIES_DIRNAME starting_commitid [RFC]"
    exit 1
fi

# series dirname without the last slash
SERIES=`echo "$1" | ${SED} 's,^(.+[^/])/+$,\1,'`

# check if this is an entirely new series, or an update to an existing one
if test -d "$1" ; then
    echo "Found: $SERIES"
    echo "IS_UPDATE=true"
    IS_UPDATE=true
else
    echo "Not found: $SERIES"
    echo "IS_UPDATE=0"
    IS_UPDATE=false
fi

STARTING_COMMIT="$2"

if test "x$3" = "xRFC" ; then
    S_PREFIX=RFC
else
    S_PREFIX=PATCH
fi

if $IS_UPDATE ; then
    # compute the versions of the old and new series

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
else
    V=1
    NEW_V=1
    NEW_SERIES="${SERIES}"
fi

# create the series directory
if mkdir ${NEW_SERIES} ; then
    echo "Created: ${NEW_SERIES}"
else
    exit 1
fi

if $IS_UPDATE ; then
    # get the previous series SUBJECT, TEXT and people involved
    NEW_COVER="${NEW_SERIES}/0000-cover-letter.patch"

    REGEX='s,^Subject: \[(.*)\] (.*)$,\2,'
    SUBJECT=`grep "^Subject: " ${COVER} | ${SED} "${REGEX}"`
    TO_LIST=`grep "^To: " ${COVER} | ${SED} 's,\$,\\\,'`
    CC_LIST=`grep "^Cc: " ${COVER} | ${SED} 's,\$,\\\,' | head --bytes=-2`
    TEXT=`cat ${COVER} | ${SED} -n '0,/^Claudio$/ {/^$/,$p}' | tail --lines=+2 | ${SED} 's,\$,\\\,'`
fi

# generate the series
git format-patch -O scripts/git.orderfile -q --cover-letter --subject-prefix="${S_PREFIX} v${NEW_V}" ${STARTING_COMMIT}
cp *.patch ${NEW_SERIES}/

if $IS_UPDATE ; then
    # apply the previous series SUBJECT, TEXT and people involved
    ${SED} -i 's,^Subject: \[(.*)\].*$,Subject: [\1] '"${SUBJECT}"',' ${NEW_COVER}

    ${SED} -i '/^\*\*\* BLURB HERE \*\*\*.*$/ a\
'"${TEXT}"'
' ${NEW_COVER}

    PATCHES=`ls ${NEW_SERIES}/*.patch`
    for PATCH in ${PATCHES} ; do

	${SED} -i '/^From: .*$/ a\
'"${TO_LIST}"'
'"${CC_LIST}"'
' ${PATCH}

    done
fi

set +e
for PATCH in ${PATCHES} ; do
    echo "Comparing ${PATCH}"
    diff ${PATCH} `echo ${PATCH} | ${SED} "s,${NEW_SERIES},.,"`
done

rm *.patch
