#!/bin/bash

BOOTSTRAP_SASS_ARCHIVE="$1"

function importFile()
{
    local IN_FILE="$1"
    local OUT_FILE="$2"

    printf "[IMPORT] %-60s => %s\n" "$1" "$2"
    cp -a "$BOOTSTRAP_TMP_DIR/$1" "$WORKING_COPY_DIR/$2"
}

if [ ! -f "$BOOTSTRAP_SASS_ARCHIVE" ] ; then
    echo "Bootstap sass archive file not found : \"$BOOTSTRAP_SASS_ARCHIVE\""
    exit 1
fi

BASE_TMP_DIR=$(mktemp -d)
BOOTSTRAP_TMP_DIR="$BASE_TMP_DIR/$(basename ${BOOTSTRAP_SASS_ARCHIVE%*.tar.gz})"
WORKING_COPY_DIR=$(readlink -f $(dirname $0)/..)

tar -xf "$BOOTSTRAP_SASS_ARCHIVE" -C "$BASE_TMP_DIR"
importFile assets/javascripts/bootstrap.min.js                       js/bootstrap.min.js
importFile assets/fonts/bootstrap/glyphicons-halflings-regular.eot   fonts/glyphicons-halflings-regular.eot
importFile assets/fonts/bootstrap/glyphicons-halflings-regular.svg   fonts/glyphicons-halflings-regular.svg
importFile assets/fonts/bootstrap/glyphicons-halflings-regular.ttf   fonts/glyphicons-halflings-regular.ttf
importFile assets/fonts/bootstrap/glyphicons-halflings-regular.woff  fonts/glyphicons-halflings-regular.woff
importFile assets/fonts/bootstrap/glyphicons-halflings-regular.woff2 fonts/glyphicons-halflings-regular.woff2
importFile assets/stylesheets/bootstrap                              css/bootstrap
importFile assets/stylesheets/_bootstrap.scss                        css/_bootstrap.scss
importFile assets/stylesheets/_bootstrap-compass.scss                css/_bootstrap-compass.scss
importFile templates/project/_bootstrap-variables.sass               css/_bootstrap-variables.sass
rm -fr "$BASE_TMP_DIR"
