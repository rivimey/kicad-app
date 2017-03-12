#!/bin/bash

# -----
# Options
# -----
THREADS=4
OSX_SDK_VER=10.11
KICAD_BRANCH=master

export COMPILER=clang
export CC=cc
export CXX=g++

#Apple clang:
export CFLAGS="-Wno-potentially-evaluated-expression -Wno-shift-negative-value"
export CXXFLAGS="-Wno-potentially-evaluated-expression -Wno-shift-negative-value"

# Homebrew/gcc6 (won't build from NSApp headers :( )
#export CFLAGS="-Wno-deprecated-declarations -Wno-unused-but-set-variable -Wno-shift-negative-value"
#export CXXFLAGS="-Wno-deprecated-declarations -Wno-unused-but-set-variable -Wno-shift-negative-value"

WX_SRC_URL="http://downloads.sourceforge.net/project/wxpython/wxPython/3.0.2.0/wxPython-src-3.0.2.0.tar.bz2"
WX_SRC_NAME=wxPython-src-3.0.2.0.tar.bz2

KICAD_GIT=https://git.launchpad.net/kicad
I18N_GIT=https://github.com/KiCad/kicad-i18n.git
LIBRARY_GIT=https://github.com/KiCad/kicad-library.git

BASE="`pwd`"
WX_PATCHES="$BASE/kicad-app/wx/patches"
NOTES_DIR="$BASE/notes"

WX_DIR="$BASE/wx"
WX_SRC="$WX_DIR/src"
WX_BUILD="$WX_DIR/build"
WX_BIN="$WX_DIR/bin"
WXPY_SRC="$WX_SRC/wxPython"

I18N_DIR="$BASE/i18n"
I18N_SRC="$I18N_DIR/src"
I18N_BUILD="$I18N_DIR/build"
I18N_BIN="$I18N_DIR/bin"

LIBRARY_DIR="$BASE/library"
LIBRARY_SRC="$LIBRARY_DIR/src"
LIBRARY_BUILD="$LIBRARY_DIR/build"
LIBRARY_BIN="$LIBRARY_DIR/bin"

KICAD_DIR="$BASE/kicad"
KICAD_SRC="$BASE/kicad"
KICAD_BUILD="$BASE/build"
KICAD_BIN="$BASE/bin"
KICAD_PATCHES="$BASE/kicad_patches"

SUPPORT_BIN="$BASE/support"

KICAD_SETTINGS=(
    "-DDEFAULT_INSTALL_PATH=/Library/Application Support/kicad"
    "-DCMAKE_OSX_DEPLOYMENT_TARGET=$OSX_SDK_VER"
    "-DwxWidgets_CONFIG_EXECUTABLE=$WX_BUILD/wx-config"
    "-DPYTHON_SITE_PACKAGE_PATH=$WX_BIN/lib/python2.7/site-packages"
    "-DCMAKE_INSTALL_PREFIX=$KICAD_BIN"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DKICAD_USE_SCH_IO_MANAGER=ON"
    "-DKICAD_INSTALL_DEMOS=OFF"
    "-DKICAD_SPICE=ON"
    "-DKICAD_USE_OCE=ON"
    "-DOCE_DIR=$(brew --prefix oce)/OCE.framework/Versions/0.18/Resources/"
    "-DKICAD_SCRIPTING=ON"
    "-DKICAD_SCRIPTING_MODULES=ON"
    "-DKICAD_SCRIPTING_WXPYTHON=ON"
    "-DPYTHON_EXECUTABLE=$(which python)"
)
# -----
# End Options
# -----

clean() {
    dirs="$NOTES_DIR $KICAD_BUILD $KICAD_BIN $WX_BUILD $WX_BIN $I18N_BUILD $I18N_BIN $LIBRARY_BUILD $LIBRARY_BIN $SUPPORT_BIN"
    echo Cleaning:
    for folder in $dirs; do
        echo "  $folder"
        rm -rf "$folder"
    done
}

check_compiler() {
    printf "Checking for Compiler... "
    if !(which $CC > /dev/null); then
        printf "Unable to find a compiler. Install a compiler and try again\n"
        exit 1
    else
        printf "${COMPILER}\n"
    fi
}

check_deps() {
    printf "Checking for Brew... "
    if !(which brew > /dev/null); then
        printf "Unable to find Brew. See http://brew.sh to install\n"
    else
        printf "Done\n"
    fi
    printf "Checking Dependencies... "
    if ! brew list gettext cmake glew cairo glm automake libtool homebrew/science/oce swig libngspice >/dev/null; then
        printf "Run brew install boost gettext cmake glew cairo glm automake libtool homebrew/science/oce swig libngspice\n"
        exit 1
    else
        printf "Done\n"
    fi
}

check_notes() {
    mkdir -p $NOTES_DIR;
}

dopatch() {
    name="$1"
    sloc="$2"
    ploc="$3"
    pfile="$4"

    if [ ! -f "$loc/$pfile" ]; then
        printf "ERROR: $name patch $pfile not found, ignoring.\n"
        exit 1
    fi

    cd "$sloc"
    printf "Patching.. $pfile  "
    printf "$name:$loc:$pfile\n" >>$NOTES_DIR/patch.log
    if patch -p0 < "$loc/$pfile" >>$NOTES_DIR/patch.log ; then
      printf ".. OK.\n"
    else
      printf ".. Failed.\n"
    fi
}

patchwx() {
    dopatch "wxWindows" "$WX_SRC" "$WX_PATCHES" "$1"
}

patchki() {
    dopatch "KiCad" "$KICAD_SRC" "$KICAD_PATCHES" "$1"
}

wx_fetch() {
    mkdir -p "$WX_DIR"
    cd "$WX_DIR"

    printf "Fetching wxPython... "
    if [ ! -f "$WX_SRC_NAME" ]; then
        printf "Downloading $WX_SRC_NAME"
        curl -L -o "$WX_SRC_NAME" "$WX_SRC_URL"
        printf "Done\n"
    else
        printf "Found\n"
    fi

    printf "Extracting wxWidgets... "
    if [ ! -d "$WX_SRC" -o ! -e "$WX_SRC/wxPython.spec" ]; then
        mkdir -p "$WX_SRC"
        cd "$WX_SRC"
        tar xf "$WX_DIR/$WX_SRC_NAME" --strip-components 1
        printf "Done\n"
    else
        printf "Found\n"
    fi

    printf "Patching wxWidgets... "
    if [ -d "$WX_PATCHES"  ]; then
        check_notes
        if [ -f "$WX_SRC/.patches_applied" ]; then
            printf "Already Patched.\n"
        else
            printf "\n"
            date >$NOTES_DIR/patch.log
            patchwx "wxwidgets-3.0.0_macosx.patch"
            patchwx "wxwidgets-3.0.0_macosx_bug_15908.patch"
            patchwx "wxwidgets-3.0.0_macosx_soname.patch"
            patchwx "wxwidgets-3.0.2_macosx_yosemite.patch"
            patchwx "wxwidgets-3.0.0_macosx_scrolledwindow.patch"
            patchwx "wxwidgets-3.0.2_macosx_retina_opengl.patch"
            patchwx "wxwidgets-3.0.2_macosx_magnify_event.patch"
            patchwx "wxwidgets-3.0.2_macosx_unicode_pasteboard.patch"
            patchwx "wxwidgets-3.0.2_macosx_sierra.patch"
            touch "$WX_SRC/.patches_applied"
            printf "Done\n"
        fi
    else
        printf "No patches.\n"
    fi
}

wx_build() {
    mkdir -p "$WX_DIR"
    cd "$WX_DIR"

    printf "Building wxWidgets... "
    if [ ! -d "$WX_BUILD" -o ! -f "$WX_BUILD/Makefile" ]; then
        mkdir -p "$WX_BUILD"
        cd "$WX_BUILD"
        export MAC_OS_X_VERSION_MIN_REQUIRED=$OSX_SDK_VER
        "$WX_SRC/configure" \
            --prefix="$KICAD_BIN" \
            --with-opengl \
            --enable-aui \
            --enable-utf8 \
            --enable-html \
            --enable-stl \
            --enable-monolithic \
            --with-libjpeg=builtin \
            --with-libpng=builtin \
            --with-regex=builtin \
            --with-libtiff=builtin \
            --with-zlib=builtin \
            --with-expat=builtin \
            --without-liblzma \
            --with-macosx-version-min=$OSX_SDK_VER \
            --disable-mediactrl # Not compatible with macOS 10.12
    fi

    if [ ! -d "$WX_BIN" ]; then
        cd "$WX_BUILD"
        make -j$THREADS
        if [ $? == 0 ]; then
            mkdir -p "$WX_BIN"
            make install
        else
            exit 1
        fi
    else
        printf "Done\n"
    fi
}

wxpy_build() {
    printf "Building wxPython... "
    if [ ! -x "$WX_BUILD/wx-config" ] ; then
        echo "ERROR: wx-config not found.. cannot continue."
    fi
    if [ ! -d "$WX_BIN/lib/python2.7/site-packages" ]; then
        cd "$WXPY_SRC"
        export MAC_OSX_VERSION_MIN_REQUIRED=$OSX_SDK_VER
        WXPYTHON_BUILD_OPTS="WX_CONFIG=$WX_BUILD/wx-config BUILD_BASE=$KICAD_BUILD UNICODE=1 WXPORT=osx_cocoa"

        WXPYTHON_PREFIX="--prefix=$KICAD_BIN"
        python "$WXPY_SRC/setup.py" build_ext $WXPYTHON_BUILD_OPTS
        if [ $? == 0 ]; then
            python "$WXPY_SRC/setup.py" install $WXPYTHON_PREFIX $WXPYTHON_BUILD_OPTS
        else
            exit 1
        fi
    else
        printf "Done\n"
    fi
}

# Kicad
kicad_fetch() {
    if [ ! -d "$KICAD_SRC" ]; then
        git clone "$KICAD_GIT" "$KICAD_SRC"
    else
        echo "Kicad Sources found."
    fi
}

kicad_pull() {
    if [ -d "$KICAD_SRC" ]; then
        git -C "$KICAD_SRC" checkout "$KICAD_BRANCH"
        git -C "$KICAD_SRC" pull
    else
        echo "ERROR: Kicad Sources not found."
    fi
}

kicad_update() {
    if [ ! -d "$KICAD_SRC" ]; then
        kicad_fetch
    else
        kicad_pull
    fi
}

kicad_patch() {
    if [ -d "$BASE/kicad_patches" ]; then
        cd "$BASE/kicad_patches"
        for patch in $(find . -type f -size +0 -name \*.patch); do
            patchki "$patch"
        done
    else
        echo "No additional KiCad patches."
    fi
}

kicad_build() {
    if [ ! -d "$KICAD_SRC" ]; then
        echo "ERROR: No KiCad source found."
    fi
    if [ ! -x "$WX_BUILD/wx-config" ] ; then
        echo "ERROR: wx-config not found.. cannot continue."
    fi

    rm -rf "$KICAD_BIN"
    mkdir -p "$KICAD_BUILD"
    cd "$KICAD_BUILD"

    cmake "${KICAD_SETTINGS[@]}" "$KICAD_SRC"
    make -j$THREADS

    mkdir -p "$KICAD_BIN"
    make install
}

kicad_rebuild() {
    rm -rf "$KICAD_BUILD"
    rm -rf "$KICAD_BIN"

    kicad_build
}

i18n_fetch() {
    if [ ! -d "$I18N_SRC" ]; then
        git clone "$I18N_GIT" "$I18N_SRC"
    else
        echo "KiCad Localisation Sources found."
    fi
}

i18n_pull() {
    if [ -d "$I18N_SRC" ]; then
        git -C "$I18N_SRC" checkout "$I18N_BRANCH"
        git -C "$I18N_SRC" pull
    else
        echo "KiCad Localisation Sources NOT found."
    fi
}

i18n_update() {
    mkdir -p "$I18N_DIR"
    cd "$I18N_DIR"

    if [ ! -d "$I18N_SRC" ]; then
        i18n_fetch
    else
        i18n_pull
    fi
}

i18n_build() {
    mkdir -p "$I18N_DIR"
    cd "$I18N_DIR"

    i18n_fetch

    rm -rf "$I18N_BIN"
    mkdir -p "$I18N_BIN"

    # Build
    mkdir -p "$I18N_BUILD"
    cd "$I18N_BUILD"

    cmake -DCMAKE_INSTALL_PREFIX="$I18N_BIN" \
          -DKICAD_I18N_PATH="$I18N_BIN/internat" \
          -DGETTEXT_MSGMERGE_EXECUTABLE="$(brew --prefix gettext)/bin/msgmerge" \
          -DGETTEXT_MSGFMT_EXECUTABLE="$(brew --prefix gettext)/bin/msgfmt" \
          "$I18N_SRC"
    make install
}

# Symbols/3d models
library_update() {
    mkdir -p "$LIBRARY_DIR"
    cd "$LIBRARY_DIR"

    if [ ! -d "$LIBRARY_SRC" ]; then
        git clone "$LIBRARY_GIT" "$LIBRARY_SRC"
    else
        git -C "$LIBRARY_SRC" checkout
        git -C "$LIBRARY_SRC" pull
    fi
}

library_build() {
    if [ ! -d "$LIBRARY_DIR" ]; then
        mkdir "$LIBRARY_DIR"
    fi

    cd "$LIBRARY_DIR"

    if [ ! -d "$LIBRARY_SRC" ]; then
        git clone "$LIBRARY_GIT" "$LIBRARY_SRC"
    fi

    mkdir -p "$LIBRARY_BUILD"
    cd "$LIBRARY_BUILD"

    if [ -d "$LIBRARY_BIN" ]; then
        rm -r "$LIBRARY_BIN"
    fi
    mkdir -p "$LIBRARY_BIN"
    cmake -DCMAKE_INSTALL_PREFIX="$LIBRARY_BIN" "$LIBRARY_SRC"
    make install
}

print_help() {
    echo "Usage: $0 [-h] [command ...]"
    echo
    echo "Options"
    echo "  -h - Help"
    #echo "  -b - Git Branch to use"
    echo
    echo "Commands"
    echo "  check_compiler - Check that a c compiler is installed"
    echo "  check_deps - Check that brew requirements are installed"
    echo "  check_wx - Fetch, Patch and Build wxwidgets"
    echo "  kicad_fetch - Fetch or update the kicad sourcecode tree"
    echo "  kicad_build - Build kicad"
    echo "  kicad_rebuild - Fresh build of kicad"
    echo "  i18n_update - Update i18n tree"
    echo "  i18n_build - Build i18n"
    echo "  library_update - update schematic symbols and 3d models"
    echo "  library_build - build schematic symbols and 3d models"
    echo "  clean - Delete the build directories for a clean build"
    echo
}

check() {
    check_compiler
    check_deps
}

fetchapp() {
    kicad_fetch
    i18n_fetch
    wx_fetch
}

buildapp() {
    wx_build
    wxpy_build
    kicad_build
    i18n_build
}


print_sequence() {
    echo "Use this sequence of commands:"
    echo "  kicad-app.sh check"
    echo "  kicad-app.sh fetchapp"
    echo "  kicad-app.sh buildapp"
    echo
}

while getopts ":hb:" opt; do
    case $opt in
        b)
            echo "Branch $OPTARG"
            ;;
        h)
            print_help
            exit 0
            ;;
        \?)
            echo "Usage: $0 [-h] [command ...]"
            exit 2
            ;;
    esac
done
shift $(expr $OPTIND - 1 )

if [ $# -eq 0 ]; then
    print_sequence
    exit 1
else
    while [ $# -gt 0 ]; do
        if [[ $(type -t $1) == function ]]; then
            $1
        else
            echo "Unknown Command: $1"
            echo "See -h for help"
            echo
        fi
        shift
    done
fi
exit 0

