#!/bin/sh

# Install all the dependencies needed to build ROCm.

if [ -z ${ROCM_INSTALL_DIR+x} ] || [ -z ${BUILD_FOLDER+x} ]; then
    echo "'install_x11.sh': one of the input variables is not set."
    exit 1
fi

cd "${BUILD_FOLDER}"

# Needed for rocBLAS
[ -e msgpack-c ] || run_command git clone -b cpp-3.0.1 https://github.com/msgpack/msgpack-c.git
cmake_install msgpack-c -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" \
    -DMSGPACK_BUILD_TESTS=OFF -DMSGPACK_BUILD_EXAMPLES=OFF

# needed for rocsolver
[ -e fmt ] || run_command git clone -b6.1.2 https://github.com/fmtlib/fmt.git
cmake_install fmt -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" \
    -DCMAKE_CXX_FLAGS=-fPIC

# -----------------------------------------------------------------------------------------------
#                                    libdrm
# -----------------------------------------------------------------------------------------------
wget_untar_cd https://github.com/mesonbuild/meson/releases/download/0.61.5/meson-0.61.5.tar.gz
export PATH="${BUILD_FOLDER}/meson-0.61.5:$PATH" # in order to use meson
if ! [ -e ninja ]; then
    run_command wget https://github.com/ninja-build/ninja/releases/download/v1.11.0/ninja-linux.zip
    unzip ninja-linux.zip
fi


wget_untar_cd https://gitlab.freedesktop.org/mesa/drm/-/archive/libdrm-2.4.111/drm-libdrm-2.4.111.tar.gz
run_command  meson.py builddir --prefix="${ROCM_INSTALL_DIR}"
run_command ninja -C builddir -j $NCORES install

# -----------------------------------------------------------------------------------------------------
#                                         sqlite3
#------------------------------------------------------------------------------------------------------
configure_build https://www.sqlite.org/snapshot/sqlite-snapshot-202205121156.tar.gz


# -----------------------------------------------------------------------------------------------------
#                                          bzip2
#------------------------------------------------------------------------------------------------------
wget_untar_cd https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
run_command make -j $NCORES install CFLAGS=-fPIC  PREFIX="${ROCM_INSTALL_DIR}"

# -----------------------------------------------------------------------------------------------------
#                                          boost
#------------------------------------------------------------------------------------------------------
cd ${BUILD_FOLDER}
# Needed fo Tensile - exactly this version!
[ -e boost_1_72_0_rc2.tar.gz ] || wget https://boostorg.jfrog.io/artifactory/main/release/1.72.0/source/boost_1_72_0_rc2.tar.gz
[ -e boost_1_72_0 ] || tar xf boost_1_72_0_rc2.tar.gz
cd boost_1_72_0
# the following is needed due to a bug in boost 1.72 installation process
OLD_CPLUS_VAR=$CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=""
( unset CPLUS_INCLUDE_PATH; unset CPATH; ./bootstrap.sh --prefix="${ROCM_INSTALL_DIR}/boost" )
export CPLUS_INCLUDE_PATH=$OLD_CPLUS_VAR
run_command ./b2 headers
run_command ./b2 -j$NCORES cxxflags=-fPIC cflags=-fPIC install toolset=gcc --with=all --prefix="${ROCM_INSTALL_DIR}/boost"

# -----------------------------------------------------------------------------------------------------
#                                          elfutils
#------------------------------------------------------------------------------------------------------
cd ${BUILD_FOLDER}
[ -e elfutils ] || run_command git clone git://sourceware.org/git/elfutils.git
run_command cd elfutils
run_command git checkout elfutils-0.187
run_command autoreconf -i -f
run_command ./configure --enable-maintainer-mode --disable-libdebuginfod --disable-debuginfod --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install

# -----------------------------------------------------------------------------------------------------
#                                          gmplib
#------------------------------------------------------------------------------------------------------
cd ${BUILD_FOLDER}
wget https://gmplib.org/download/gmp/gmp-6.2.1.tar.xz
run_command tar -xf gmp-6.2.1.tar.xz
run_command cd ${BUILD_FOLDER}/gmp-6.2.1
run_command ./configure --prefix=${ROCM_INSTALL_DIR}
run_command make -j $NCORES
run_command make install
