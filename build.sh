#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# -----------------------------
# Function Definitions
# -----------------------------

# Function to display usage information
usage() {
    echo -e "Usage: $0 [options]

Options:
  -c, --clean         Clean the out directories before building
  -m, --menuconfig    Run make menuconfig before building
  -h, --help          Display this help message

Examples:
  $0 --clean --menuconfig
"
    exit 1
}

# Function to parse command-line arguments
parse_args() {
    CLEAN=false
    MENUCONFIG=false

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -c|--clean)
                CLEAN=true
                shift
                ;;
            -m|--menuconfig)
                MENUCONFIG=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo -e "${red}Unknown option: $1${default}"
                usage
                ;;
        esac
    done
}

# -----------------------------
# Color Definitions
# -----------------------------
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
cyan='\033[0;36m'
yellow='\033[0;33m'
blue='\033[0;34m'
default='\033[0m'

# -----------------------------
# Variable Definitions
# -----------------------------
CLANG_VER="clang-r522817"
ROM_PATH="/mnt/QuickBoi/LineageOS/22"
CLANG_DIR="$ROM_PATH/prebuilts/clang/host/linux-x86/$CLANG_VER"
KERNEL_DIR="$PWD"
Anykernel_DIR="$KERNEL_DIR/AnyKernel3/"
DATE=$(date +"%d%m%Y")
TIME=$(date +"%H.%M.%S")
KERNEL_NAME="NoName"
DEVICE="MI_A3"
ANDROID_VER="[a10+a15]"
KERNEL_SUBVER="[V9]"
FINAL_ZIP="${DEVICE}-${KERNEL_NAME}-${KERNEL_SUBVER}-${ANDROID_VER}-${DATE}.zip"

BUILD_START=$(date +"%s")

# -----------------------------
# Export and Path Setup
# -----------------------------
export TARGET_KERNEL_CLANG_COMPILE=true
export PATH="$CLANG_DIR/bin:$PATH"

# -----------------------------
# Parse Command-Line Arguments
# -----------------------------
parse_args "$@"

# -----------------------------
# Clean Out Directories if Flag is Set
# -----------------------------
if [ "$CLEAN" = true ]; then
    echo -e "${yellow}***********************************************${default}"
    echo -e "${yellow}                Cleaning out directories        ${default}"
    echo -e "${yellow}***********************************************${default}"
    rm -rf out
    rm -rf $Anykernel_DIR/Image.gz-dtb
    rm -rf $Anykernel_DIR/dtbo.img
fi

# -----------------------------
# Display Build Start Message
# -----------------------------
echo -e "${cyan}***********************************************${default}"
echo  "          Compiling NoName Kernel              "
echo -e "${cyan}***********************************************${default}"

# -----------------------------
# Optional: Run make menuconfig
# -----------------------------
if [ "$MENUCONFIG" = true ]; then
    echo -e "${blue}Running make menuconfig...${default}"

    make O=out ARCH=arm64 vendor/laurel_sprout-perf_defconfig
    make -j"$(nproc --all)" O=out ARCH=arm64 \
        CC=clang \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE="$CLANG_DIR/bin/llvm-" \
        LLVM=1 \
        LLVM_IAS=1 \
        menuconfig
    exit
fi

# -----------------------------
# Build Process
# -----------------------------
mkdir -p out
make O=out ARCH=arm64 vendor/laurel_sprout-perf_defconfig

# Compile the kernel
echo -e "${blue}Starting kernel compilation...${default}"
make -j"$(nproc --all)" O=out ARCH=arm64 \
    CC=clang \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE="$CLANG_DIR/bin/llvm-" \
    LLVM=1 \
    LLVM_IAS=1 \
    Image.gz-dtb \
    dtbo.img

echo -e "${yellow}***********************************************${default}"
echo  "                Zipping Kernel                     "
echo -e "***********************************************${default}"

# -----------------------------
# Create the Flashable Zip
# -----------------------------
cp out/arch/arm64/boot/Image.gz-dtb "$Anykernel_DIR"
cp out/arch/arm64/boot/dtbo.img "$Anykernel_DIR"
cd "$Anykernel_DIR"

zip -r9 "$FINAL_ZIP" * \
    -x "*.git*" \
    -x "README.md" \
    -x "*placeholder*" \
    -x "*.zip"

echo -e "${cyan}***********************************************${default}"
echo  "                 Cleaning up                    "
echo -e "***********************************************${default}"

# -----------------------------
# Build Completion Message
# -----------------------------
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))
echo -e "${green}Build completed in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds.${default}"
