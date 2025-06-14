#!/bin/sh -e

. debian/misc_files/print_dist.inc

sed -e "s|@BUILD_DIST@|$(print_dist)|" \
    -e "/@PRINT_DIST@/c\\$(sed '$!s|$|\\|' debian/misc_files/print_dist.inc)"

exit $?
