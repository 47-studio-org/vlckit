#!/bin/sh
# Copyright (C) Pierre d'Herbemont, 2010
# Copyright (C) Felix Paul Kühne, 2012-2013

set -e

PLATFORM=iphoneos
SDK=7.0
SDK_MIN=6.1
VERBOSE=no
CONFIGURATION="Release"
NONETWORK=no
SKIPLIBVLCCOMPILATION=no

TESTEDHASH=85aca9192

usage()
{
cat << EOF
usage: $0 [-s] [-v] [-k sdk]

OPTIONS
   -k       Specify which sdk to use (see 'xcodebuild -showsdks', current: ${SDK})
   -v       Be more verbose
   -s       Build for simulator
   -d       Enable Debug
   -n       Skip script steps requiring network interaction
   -l       Skip libvlc compilation
EOF
}

spushd()
{
     pushd "$1" 2>&1> /dev/null
}

spopd()
{
     popd 2>&1> /dev/null
}

info()
{
     local green="\033[1;32m"
     local normal="\033[0m"
     echo "[${green}info${normal}] $1"
}

buildxcodeproj()
{
    local target="$2"
    if [ "x$target" = "x" ]; then
        target="$1"
    fi

    info "Building $1 ($target, ${CONFIGURATION})"

    local extra=""
    if [ "$PLATFORM" = "Simulator" ]; then
        extra="ARCHS=i386"
    fi

    xcodebuild -project "$1.xcodeproj" \
               -target "$target" \
               -sdk $PLATFORM$SDK \
               -configuration ${CONFIGURATION} ${extra} \
               IPHONEOS_DEPLOYMENT_TARGET=${SDK_MIN} > ${out}
}

while getopts "hvsdnlk:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             VERBOSE=yes
             ;;
         s)
             PLATFORM=iphonesimulator
             ;;
         d)  CONFIGURATION="Debug"
             ;;
         n)
             NONETWORK=yes
             ;;
         l)
             SKIPLIBVLCCOMPILATION=yes
             ;;
         k)
             SDK=$OPTARG
             ;;
         ?)
             usage
             exit 1
             ;;
     esac
done
shift $(($OPTIND - 1))

out="/dev/null"
if [ "$VERBOSE" = "yes" ]; then
   out="/dev/stdout"
fi

if [ "x$1" != "x" ]; then
    usage
    exit 1
fi

# Get root dir
spushd .
aspen_root_dir=`pwd`
spopd

info "Preparing build dirs"

mkdir -p MobileVLCKit/ImportedSources

spushd MobileVLCKit/ImportedSources

if [ "$NONETWORK" != "yes" ]; then
if ! [ -e vlc ]; then
git clone git://git.videolan.org/vlc/vlc-2.1.git vlc
info "Applying patches to vlc.git"
cd vlc
git checkout -B localAspenBranch ${TESTEDHASH}
git branch --set-upstream-to=origin/master localAspenBranch
git am ../../patches/*.patch
if [ $? -ne 0 ]; then
git am --abort
info "Applying the patches failed, aborting git-am"
exit 1
fi
cd ..
else
cd vlc
git reset --hard ${TESTEDHASH}
git am ../../patches/*.patch
cd ..
fi
fi

spopd

#
# Build time
#

info "Building"

spushd MobileVLCKit/ImportedSources

if [ "$SKIPLIBVLCCOMPILATION" != "yes" ]; then
spushd vlc/extras/package/ios
info "Building vlc"
args=""
if [ "$VERBOSE" = "yes" ]; then
    args="${args} -v"
fi
if [ "$PLATFORM" = "iphonesimulator" ]; then
    args="${args} -s"
    ./build.sh -a i386 ${args} -k "${SDK}" && ./build.sh -a x86_64 ${args} -k "${SDK}"
else
    ./build.sh -a armv7 ${args} -k "${SDK}" && ./build.sh -a armv7s ${args} -k "${SDK}" && ./build.sh -a arm64 ${args} -k "${SDK}"
fi

spopd
fi

spopd # MobileVLCKit/ImportedSources

buildxcodeproj MobileVLCKit "Aggregate static plugins"
buildxcodeproj MobileVLCKit "MobileVLCKit"

info "Build completed"
