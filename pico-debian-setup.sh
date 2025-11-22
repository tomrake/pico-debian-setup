#! /bin/bash

# Exit on error
set -e

# TODO check for linux system here

# The following is extracted from pico-vscode/data/0.18.0/supportedToolchains.ini
# for version 0.18.0 of the VSCode plugin
#
#
#
# [14_2_Rel1]
# win32_x64 = https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-mingw-w64-i686-arm-none-eabi.zip
# darwin_arm64 = https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-darwin-arm64-arm-none-eabi.tar.xz
# darwin_x64 = https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-darwin-x86_64-arm-none-eabi.tar.xz
# linux_x64 = https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi.tar.xz
# linux_arm64 = https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-aarch64-arm-none-eabi.tar.xz
# [RISCV_ZCB_RPI_2_2_0_3]
# win32_x64 = https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.2.0-3/riscv-toolchain-15-x64-win.zip
# darwin_arm64 = https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.2.0-3/riscv-toolchain-15-mac.zip
# darwin_x64 = https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.2.0-3/riscv-toolchain-15-mac.zip
# linux_x64 = https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.2.0-3/riscv-toolchain-15-x86_64-lin.tar.gz
# linux_arm64 = https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.2.0-3/riscv-toolchain-15-aarch64-lin.tar.gz

SOURCE_ARM_TOOLCHAIN="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi.tar.xz"
SOURCE_RISCV_TOOLCHAIN="https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.2.0-3/riscv-toolchain-15-x86_64-lin.tar.gz"


# Number of cores when running make
JNUM=4



# Where will the output go?
echo "Base Directory in ${PWD}"
OUTDIR="$(pwd)/pico"

# Install dependencies

OPENOCD_TAG="sdk-2.2.0"

# Get the toolschains for pico arm and riscv

TOOLCHAINS="${OUTDIR}/pico-toolchains"
mkdir -p "${TOOLCHAINS}"

if [[ "${SKIP_ARM_TOOLCHAIN}" == 1 ]]; then
    echo "Skpping arm toolchain"
else
    cd "${TOOLCHAINS}"
    CHAIN="arm"
    mkdir "${CHAIN}"
    cd "${CHAIN}"
    mkdir "tmp"
    cd "tmp"
    curl  -L "${SOURCE_ARM_TOOLCHAIN}" > ./chain.zip
    unzip -qq -d "../" "./chain.zip"
    rm ./chain.zip
    cd ..
    rm -rf "tmp"


    PICO_ARM_TOOLCHAIN_PATH="${TOOLCHAINS}/${CHAIN}"
    VARNAME="PICO_ARM_TOOLCHAIN_PATH"
    echo "Adding ${VARNAME} to ~/.bashrc"
    echo "export ${VARNAME}=${PICO_ARM_TOOLCHAIN_PATH}" >> ~/.bashrc
    export ${VARNAME}=$PICO_ARM_TOOLCHAIN_PATH

    PICO_TOOLCHAIN_PATH="${TOOLCHAINS}/${CHAIN}"
    VARNAME="PICO_TOOLCHAIN_PATH"
    echo "Adding ${VARNAME} to ~/.bashrc"
    echo "export ${VARNAME}=${PICO_TOOLCHAIN_PATH}" >> ~/.bashrc
    export ${VARNAME}=${PICO_TOOLCHAIN_PATH}
fi

#### RISV
if [[ "${SKIP_RISCV_TOOLCHAIN}" == 1 ]]; then
       echo "Skipping riscv toolchain"
    else
	cd "${OUTDIR}"
	cd "${TOOLCHAINS}"


	CHAIN="riscv"
	mkdir "${CHAIN}"
	cd $CHAIN
	mkdir "tmp"
	cd "tmp"
	curl  -L "${SOURCE_RISCV_TOOLCHAIN}" > ./chain.zip
	unzip -qq -d "../" "./chain.zip"
	rm ./chain.zip
	cd ..
	rm -rf "tmp"
	# Define PICO_RISCV_TOOLCHAIN_PATH in ~/.bashrc
	PICO_RISCV_TOOLCHAIN_PATH="${TOOLCHAINS}/${CHAIN}"
        VARNAME="PICO_RISCV_TOOLCHAIN_PATH"
        echo "Adding ${VARNAME} to ~/.bashrc"
        echo "export ${VARNAME}=${PICO_RISCV_TOOLCHAIN_PATH}" >> ~/.bashrc
        export ${VARNAME}=${PICO_RISCV_TOOLCHAIN_PATH}
fi



cd $OUTDIR

echo "Creating ${OUTDIR}"
# Create pico directory to put everything in
mkdir -p ${OUTDIR}
cd ${OUTDIR}




echo "Installation = ${OUTDIR}"



# Clone sw repos
GITHUB_PREFIX="https://github.com/raspberrypi/"
GITHUB_SUFFIX=".git"
SDK_BRANCH="master"

for REPO in sdk examples extras playground
do
    DEST="${OUTDIR}/pico-${REPO}"

    if [ -d ${DEST} ]; then
        echo "${DEST} already exists so skipping"
    else
        REPO_URL="${GITHUB_PREFIX}pico-${REPO}${GITHUB_SUFFIX}"
        echo "Cloning ${REPO_URL}"
        git clone -b ${SDK_BRANCH} ${REPO_URL}

        # Any submodules
        cd ${DEST}
        git submodule update --init
        cd ${OUTDIR}

        # Define PICO_SDK_PATH in ~/.bashrc
        VARNAME="PICO_${REPO^^}_PATH"
        echo "Adding $VARNAME to ~/.bashrc"
        echo "export $VARNAME=${DEST}" >> ~/.bashrc
        export ${VARNAME}=${DEST}
    fi
done

cd ${OUTDIR}

# Pick up new variables we just defined
source ~/.bashrc

# Debugprobe and picotool
for REPO in picotool debugprobe
do
    DEST="${OUTDIR}/${REPO}"
    REPO_URL="${GITHUB_PREFIX}${REPO}${GITHUB_SUFFIX}"
    if [[ "${REPO}" == "picotool" ]]; then
      git clone -b ${SDK_BRANCH} ${REPO_URL}
    else
      git clone ${REPO_URL}
    fi

    # Build both
    cd ${DEST}
    git submodule update --init
    cmake -S . -B build -GNinja
    cmake --build build

    if [[ "${REPO}" == "picotool" ]]; then
        echo "Installing picotool"
        sudo cmake --install "$DEST/picotool"
	# picoprobe and other depend on this directory existing.
        VARNAME="PICOTOOL_FETCH_FROM_GIT_PATH"
	echo "Adding $VARNAME to ~/.bashrc"
        echo "export $VARNAME=$DEST" >> ~/.bashrc
        export ${VARNAME}=$DEST
    fi

    cd ${OUTDIR}
done

# Build blink and hello world for default boards
cd pico-examples
for board in pico pico_w pico2 pico2_w
do
    build_dir="build_${board}"
    cmake -S . -B ${build_dir} -GNinja -DPICO_BOARD=${board} -DCMAKE_BUILD_TYPE=Debug
    examples="blink hello_serial hello_usb"
    echo "Building $examples for ${board}"
    cmake --build ${build_dir} --target "${examples}"
done

cd ${OUTDIR}

if [ -d openocd ]; then
    echo "openocd already exists so skipping"
    SKIP_OPENOCD=1
fi

if [[ "${SKIP_OPENOCD}" == 1 ]]; then
    echo "Won't build OpenOCD"
else
    # Build OpenOCD
    echo "Building OpenOCD"
    cd ${OUTDIR}
    OPENOCD_INSTALL_DIR="${OUTDIR}/openocd/"
    OPENOCD_CONFIGURE_ARGS="--enable-ftdi --enable-sysfsgpio --enable-bcm2835gpio --disable-werror --enable-linuxgpiod"

    git clone "${GITHUB_PREFIX}openocd${GITHUB_SUFFIX}" -b ${OPENOCD_TAG} --depth=1
    cd openocd
    ./bootstrap
    ./configure --prefix="${OPENOCD_INSTALL_DIR}" ${OPENOCD_CONFIGURE_ARGS}
    make -j${JNUM}
    sudo make install
fi

cd ${OUTDIR}


