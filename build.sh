#!/bin/bash

# Colors
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
cyan='\033[0;36m'
yellow='\033[0;33m'
blue='\033[0;34m'
default='\033[0m'

# Define variables
CLANG_VER="clang-r522817"
ROM_PATH="$HOME/linux-x86"
PCLANG_DIR=$ROM_PATH/$CLANG_VER
KERNEL_DIR=$PWD
Anykernel_DIR="$KERNEL_DIR/AnyKernel3/"
DATE=$(date +"[%d%m%Y]")
TIME=$(date +"%H.%M.%S")
KERNEL_NAME="NoName"
DEVICE="MI_A3"
ANDROID_VER="[a12+]"
KERNEL_SUBVER="[V9]"
FINAL_ZIP="$DEVICE-$KERNEL_NAME-$KERNEL_SUBVER-$ANDROID_VER-$DATE"

CLANG_PATH_FILE="$HOME/.clang_path"

rm -rf $Anykernel_DIR/MI_A3-NoName*.zip
rm -rf $Anykernel_DIR/Image.gz-dtb
rm -rf $Anykernel_DIR/dtbo.img

BUILD_START=$(date +"%s")

# Initialize variables
USE_PCLANG=false
CLEANUP=true

# Parse flags
while getopts "pd" flag; do
    case "${flag}" in
        p) USE_PCLANG=true ;;
        d) CLEANUP=false ;;
    esac
done

# Determine CLANG_DIR
if $USE_PCLANG; then
    CLANG_DIR="$PCLANG_DIR"
    if [ ! -d "$CLANG_DIR" ]; then
        echo -e "${red}Error: PCLANG_DIR $CLANG_DIR does not exist. Exiting.${default}"
        exit 1
    fi
    echo -e "${blue}Using PCLANG_DIR: $CLANG_DIR${default}"
else
    # Check if the CLANG path is saved in the file
    if [ -f "$CLANG_PATH_FILE" ]; then
        CLANG_DIR=$(cat "$CLANG_PATH_FILE")
      
        # Confirm if CLANG_DIR exists in the filesystem
        if [ ! -d "$CLANG_DIR" ]; then
            echo -e "${yellow}Warning: Saved CLANG directory does not exist. Searching again...${default}"
            CLANG_DIR=""
        fi
    else
        # File does not exist, need to find CLANG_DIR
        CLANG_DIR=""
    fi
    
    # If CLANG_DIR is empty, search for it
    if [ -z "$CLANG_DIR" ]; then
        CLANG_DIR=$(find "/" -type d -name "$CLANG_VER" -print -quit 2>/dev/null)
      
        if [ -z "$CLANG_DIR" ]; then
            echo -e "${red}Error: $CLANG_VER directory not found in System. Exiting.${default}"
            exit 1
        fi
      
        # Save the found path to the file for future runs
        echo "$CLANG_DIR" > "$CLANG_PATH_FILE"
    else
        # Check if the saved CLANG_VER matches the current one
        SAVED_CLANG_VER=$(basename "$CLANG_DIR")
        if [ "$SAVED_CLANG_VER" != "$CLANG_VER" ]; then
            echo -e "${yellow}CLANG_VER has changed from $SAVED_CLANG_VER to $CLANG_VER. Searching again...${default}"
            CLANG_DIR=$(find "/" -type d -name "$CLANG_VER" -print -quit 2>/dev/null)
        
            if [ -z "$CLANG_DIR" ]; then
                echo -e "${red}Error: $CLANG_VER directory not found in System. Exiting.${default}"
                exit 1
            fi
        
            # Save the new path to the file for future runs
            echo "$CLANG_DIR" > "$CLANG_PATH_FILE"
        fi
    fi
fi

# Export variables
export TARGET_KERNEL_CLANG_COMPILE=true
PATH="$CLANG_DIR/bin:${PATH}"

echo -e "***********************************************"
echo "          Compiling NoName Kernel              "
echo -e "***********************************************"

# Finally build it
mkdir -p out
make O=out ARCH=arm64 vendor/laurel_sprout-perf_defconfig
make -j$(nproc --all) O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE="$CLANG_DIR/bin/llvm-" LLVM=1 LLVM_IAS=1 Image.gz-dtb dtbo.img

echo -e "$yellow***********************************************"
echo "                Zipping Kernel                     "
echo -e "***********************************************"

# Create the flashable zip
cp out/arch/arm64/boot/Image.gz-dtb "$Anykernel_DIR"
cp out/arch/arm64/boot/dtbo.img "$Anykernel_DIR"
cd "$Anykernel_DIR" || exit
zip -r9 "$FINAL_ZIP.zip" * -x .git README.md *placeholder

echo -e "$cyan***********************************************"
echo "                 Cleaning up                    "
echo -e "***********************************************$default"

# Cleanup if CLEANUP is true
if ${CLEANUP:-true}; then
  cd "$KERNEL_DIR" || exit
  rm -rf "$Anykernel_DIR/Image.gz-dtb"
  rm -rf "$Anykernel_DIR/dtbo.img"
  rm -rf out
fi

# Build complete
BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$green Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$default"
