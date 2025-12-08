#! /bin/bash

function check_file_test() {
    if [[ -f "$1" ]]; then
	echo "$1 was found"
    else
	echo "$1 was not found."
	exit 1
    fi
}



# Exit on error
set -e

# Set for debuging partial builds
SKIP_ARM_TOOLCHAIN=
SKIP_RISCV_TOOLCHAIN=
SKIP_TOOLS=

if grep -q Raspberry /proc/cpuinfo; then
    ON_PI=1
    echo "Running on a Raspberry Pi"
else
    SKIP_UART=1
fi


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

echo "### Start pico-debian-setup.sh on `date`" >> ~/.bashrc
# Get the toolschains for pico arm and riscv
TOOL_ARCHIVE="chain.gz"
TOOLCHAINS="${OUTDIR}/pico-toolchains"


mkdir -p "${TOOLCHAINS}"


if [[ "${SKIP_ARM_TOOLCHAIN}" == 1 ]]; then
    echo "Skpping arm toolchain"
else
    cd "${TOOLCHAINS}"
    CHAIN="arm"
    mkdir -p "${TOOLCHAINS}/${CHAIN}/tmp"
    cd "${TOOLCHAINS}/${CHAIN}/tmp"
    curl  -L "${SOURCE_ARM_TOOLCHAIN}" > "${TOOL_ARCHIVE}"
    #    unzip -qq -d "../" "./chain.zip"
    tar  -xf "${TOOL_ARCHIVE}" --strip-components=1 -C ".."
    # The crosscomp;iler is unpacked - Fail things don't look good.
    check_file_test "${TOOLCHAINS}/${CHAIN}/bin/arm-none-eabi-gcc"

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
	mkdir -p "${TOOLCHAINS}/${CHAIN}/tmp"
	cd "${TOOLCHAINS}/${CHAIN}/tmp"
	curl  -L "${SOURCE_RISCV_TOOLCHAIN}" > "${TOOL_ARCHIVE}"
	#    unzip -qq -d "../" "./chain.zip"
	tar  -xf "${TOOL_ARCHIVE}" -C ".."
	# The crosscomp;iler is unpacked - Fail things don't look good.
	#CHECKFILE="${TOOLCHAINS}/${CHAIN}/bin/riscv32-unknown-elf-gcc"
	check_file_test "${TOOLCHAINS}/${CHAIN}/bin/riscv32-unknown-elf-gcc"

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
	check_file_test "${DEST}/README.md"

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
if [[ "${SKIP_TOOLS}" == 1 ]]; then
    echo "Skipping picotool and debugprobe"
else
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
	TOOL_BUILD_DIR="${DEST}/build"
	
	if [[ "${REPO}" == "picotool" ]]; then
            echo "Installing picotool"
            cmake --install build  --prefix "${DEST}/picotool"
	    # picoprobe and other depend on this directory existing.
	    check_file_test "${DEST}/picotool/bin/picotool"

	    VARNAME="PICOTOOL_FETCH_FROM_GIT_PATH"
	    echo "Adding $VARNAME to ~/.bashrc"
            echo "export $VARNAME=$DEST" >> ~/.bashrc
            export ${VARNAME}=$DEST

	    VARNAME="PICOTOOL_DIR"
	    echo "Adding $VARNAME to ~/.bashrc"
            echo "export $VARNAME=${DEST}/picotool/bin" >> ~/.bashrc
            export ${VARNAME}="${DEST}/picotool/bin"
	    
	    VARNAME="PICOTOOL_NAME"
	    echo "Adding $VARNAME to ~/.bashrc"
            echo "export $VARNAME=picotool" >> ~/.bashrc
            export ${VARNAME}="picotool"
	    
	elif [[ "${REPO}" == "debugprobe" ]]; then
	    for PROD in debugprobe.bin debugprobe.elf debugprobe.uf2
	    do
		check_file_test "${TOOL_BUILD_DIR}/${PROD}"
	    done
	    VARNAME="DEBUGPROBE_PATH"
	    echo "Adding $VARNAME to ~/.bashrc"
            echo "export $VARNAME=${TOOL_BUILD_DIR}" >> ~/.bashrc
            export ${VARNAME}=$TOOL_BUILD_DIR
	fi

	cd ${OUTDIR}
    done
fi
source ~/.bashrc
# Build blink and hello world for default boards
cd pico-examples
for board in pico pico_w pico2 pico2_w
do
    build_dir="build_${board}"
    cmake -S . -B "${build_dir}" -GNinja -DPICO_BOARD=${board} -DCMAKE_BUILD_TYPE=Debug
    examples="blink hello_serial hello_usb"
    echo "Building $examples for ${board}"
    cmake --build "${build_dir}" --target ${examples}
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
    OPENOCD_INSTALL_DIR="${OUTDIR}/openocd/openocd/"
    OPENOCD_INSTALL_PREFIX=
    OPENOCD_CONFIGURE_ARGS="--enable-ftdi  --disable-werror"
    if [[ "${ON_PI}" == 1 ]]; then
	OPENOCD_CONFIGURE_ARGS="${OPENOCD_CONFIGURE_ARGS} --enable-sysfsgpio --enable-bcm2835gpio  --enable-linuxgpiod"
    elif [ `cat /etc/debian_version` \> 12.999 ];  then
	OPENOCD_INSTALL_PREFIX="--prefix=${OPENOCD_INSTALL_DIR}"
    else
	OPENOCD_CONFIGURE_ARGS="${OPENOCD_CONFIGURE_ARGS} --enable-internal-jimtcl"
	OPENOCD_INSTALL_PREFIX="--prefix=${OPENOCD_INSTALL_DIR}"
    fi
    git clone "${GITHUB_PREFIX}openocd${GITHUB_SUFFIX}" -b ${OPENOCD_TAG} --depth=1
    cd openocd
    if [[ "${ON_PI}" == 1 ]]; then
	echo "No update to get internal jimtcl"
    else
	git submodule update --init
    fi
    ./bootstrap
    echo "outdir: ${OUTDIR}" >> "${OUTDIR}/openocd.log"
    echo "install dir: ${OPENOCD_INSTALL_DIR}"  >> "${OUTDIR}/openocd.log"
    echo "prefix: ${OPENOCD_INSTALL_PREFIX}" >> "${OUTDIR}/openocd.log"
    ./configure ${OPENOCD_INSTALL_PREFIX} ${OPENOCD_CONFIGURE_ARGS}
    make -j${JNUM}
    make install
    OPENOCD_BINARY="$OPENOCD_INSTALL_DIR/bin/openocd"
    check_file_test "${OPENOCD_BINARY}"
    FILE="${OPENOCD_BINARY}"
    VARNAME="OPENOCD_DIR"
    echo "Adding $VARNAME to ~/.bashrc"
    echo "export $VARNAME=$OPENOCD_INSTALL_DIR/bin" >> ~/.bashrc
    export ${VARNAME}="$OPENOCD_DIR_INSTALL/bin"

    VARNAME="OPENOCD_NAME"
    echo "Adding $VARNAME to ~/.bashrc"
    echo "export $VARNAME=openocd" >> ~/.bashrc
    export ${VARNAME}="openocd"  
fi

cd ${OUTDIR}


# Enable UART
if [[ "$SKIP_UART" == 1 ]]; then
    echo "Skipping uart configuration"
else
    sudo apt install -y $UART_DEPS
    echo "Disabling Linux serial console (UART) so we can use it for pico"

    # Enable UART hardware
    sudo raspi-config nonint do_serial_hw 0
    # Disable console over serial port
    sudo raspi-config nonint do_serial_cons 1

    echo "You must run sudo reboot to finish UART setup"
fi
