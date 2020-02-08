#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

# Check autobuild is around or fail
if [ -z "$AUTOBUILD" ] ; then
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# Load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

# Note: fmod studio api is provided in 3 flavors (one per platform) of precompiled binaries. We do not have access to source code.
FMOD_ROOT_NAME="$(pwd)/"
FMOD_VERSION="20007"
FMOD_VERSION_PRETTY="2.00.07"

case "$AUTOBUILD_PLATFORM" in
    windows*)
    WINSOURCE="FMOD_Studio_API_Windows"
    FMOD_SOURCE_DIR="$FMOD_ROOT_NAME$WINSOURCE"
    ;;
    darwin*)
    DARWINSOURCE="FMOD_Studio_API_macOS"
    FMOD_SOURCE_DIR="$FMOD_ROOT_NAME$DARWINSOURCE"
    ;;
    linux*)
    LINUXSOURCE="FMOD_Studio_API_Linux"
    FMOD_SOURCE_DIR="$FMOD_ROOT_NAME$LINUXSOURCE"
    ;;
esac

case "$AUTOBUILD_PLATFORM" in
    windows*)
        # We can't run the NSIS installer as admin in TC
        # so we do this part manually and put the whole lot
        # into the repo instead.
        #
        bash_install_dir="$(pwd)/$FMOD_ROOT_NAME$FMOD_VERSION$FMOD_PLATFORM"
        mkdir -p $bash_install_dir
        win_install_dir=`cygpath -w "$bash_install_dir"`
        #
        # This will invoke the UAC dialog to confirm permission before
        # proceeding.  You can run the build on a 'modified' system with
        # permissions granted to the build account or you might be able
        # to get to the dialog using remote desktop.  Either way, manual
        # preparation for this is required.
        #
        chmod +x "$FMOD_ARCHIVE"
        cmd.exe /c "$FMOD_ARCHIVE /S /D=$win_install_dir"
        if [ ! -d "$win_install_dir" ]; then
            echo "Please run $FMOD_ARCHIVE as administrator and install to  $win_install_dir"
            exit 1
        fi
    ;;
esac

stage="$(pwd)/stage"
stage_release="$stage/lib/release"
stage_debug="$stage/lib/debug"

# Create the staging license folder
mkdir -p "$stage/LICENSES"

# Create the staging include folders
mkdir -p "$stage/include/fmodstudio"

#Create the staging debug and release folders
mkdir -p "$stage_debug"
mkdir -p "$stage_release"

echo "${FMOD_VERSION_PRETTY}" > "${stage}/VERSION.txt"
COPYFLAGS=""
pushd "$FMOD_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
        COPYFLAGS="-dR --preserve=mode,timestamps"
            cp $COPYFLAGS "api/core/lib/x86/fmodL_vc.lib" "$stage_debug"
            cp $COPYFLAGS "api/core/lib/x86/fmod_vc.lib" "$stage_release"
            cp $COPYFLAGS "api/core/lib/x86/fmodL.dll" "$stage_debug"
            cp $COPYFLAGS "api/core/lib/x86/fmod.dll" "$stage_release"
            cp $COPYFLAGS "api/studio/lib/x86/fmodstudioL_vc.lib" "$stage_debug"
            cp $COPYFLAGS "api/studio/lib/x86/fmodstudio_vc.lib" "$stage_release"
            cp $COPYFLAGS "api/studio/lib/x86/fmodstudioL.dll" "$stage_debug"
            cp $COPYFLAGS "api/studio/lib/x86/fmodstudio.dll" "$stage_release"
        ;;

        "windows64")
        COPYFLAGS="-dR --preserve=mode,timestamps"
            cp $COPYFLAGS "api/core/lib/x64/fmodL_vc.lib" "$stage_debug"
            cp $COPYFLAGS "api/core/lib/x64/fmod_vc.lib" "$stage_release"
            cp $COPYFLAGS "api/core/lib/x64/fmodL.dll" "$stage_debug"
            cp $COPYFLAGS "api/core/lib/x64/fmod.dll" "$stage_release"
            cp $COPYFLAGS "api/studio/lib/x64/fmodstudioL_vc.lib" "$stage_debug"
            cp $COPYFLAGS "api/studio/lib/x64/fmodstudio_vc.lib" "$stage_release"
            cp $COPYFLAGS "api/studio/lib/x64/fmodstudioL.dll" "$stage_debug"
            cp $COPYFLAGS "api/studio/lib/x64/fmodstudio.dll" "$stage_release"
        ;;

        "darwin")
            cp "api/core/lib/libfmod.dylib" "$stage_release"
            cp "api/studio/lib/libfmodstudio.dylib" "$stage_release"
            pushd "$stage_debug"
              fix_dylib_id libfmodstudioL.dylib
              fix_dylib_id libfmodL.dylib
            popd
            pushd "$stage_release"
              fix_dylib_id libfmodstudio.dylib
              fix_dylib_id libfmod.dylib
            popd
        ;;

        "linux64")
            # Copy the relevant stuff around
            cp -a api/core/lib/x86_64/libfmod.so* "$stage_release"
            cp -a api/studio/lib/x86_64/libfmodstudio.so* "$stage_release"
        ;;
    esac

    # Copy the headers
    cp $COPYFLAGS api/core/inc/*.h "$stage/include/fmodstudio"
    cp $COPYFLAGS api/core/inc/*.hpp "$stage/include/fmodstudio"
    cp $COPYFLAGS api/studio/inc/*.h "$stage/include/fmodstudio"
    cp $COPYFLAGS api/studio/inc/*.hpp "$stage/include/fmodstudio"

    # Copy License (extracted from the readme)
    cp "doc/LICENSE.TXT" "$stage/LICENSES/fmodstudio.txt"
popd

