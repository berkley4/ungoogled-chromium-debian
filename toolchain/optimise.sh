#!/bin/sh
set -e

DIR_NAME=$(dirname $0)
SCRIPT_NAME=$(basename $0)

USAGE="Usage: $SCRIPT_NAME [r|reverse]"

find_files() {
  find $DIR_NAME/llvm-project -path ./llvm-project/build -prune \
    -o -type f -name $1 -print
}


if [ ! -d $DIR_NAME/llvm-project ]; then
  printf "Cannot find $DIR_NAME/llvm-project"
  exit 1
fi

case $1 in
  r|reverse)
    find_files CMakeLists.txt.pre_flags | \
      while read l; do
        mv $l ${l%.pre_flags}
      done
  ;;

  "")
    find_files CMakeLists.txt | \
      while read l; do
        if [ -f $l.pre_flags ]; then
          printf '%s\n' "File exists: $l.pre_flags"
          printf '%s\n' "Reverse previous patching by running: $SCRIPT_NAME r"
          exit 1
        fi

        mv $l $l.pre_flags
        cat $DIR_NAME/build_options.txt $l.pre_flags > $l
      done
  ;;

  *)
    printf '%s\n' "$USAGE"
    exit 0

  ;;
esac


exit $?
