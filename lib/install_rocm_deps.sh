#!/bin/sh

# Install all the dependencies needed to build ROCm.
if [ -z ${ROCM_DEPS_INSTALL_DIR+x} ] || [ -z ${BUILD_FOLDER+x} ]; then
    echo "'install_x11.sh': one of the input variables is not set."
    exit 1
fi
INSTALL_DIR="${ROCM_DEPS_INSTALL_DIR}"
ROCM_DEPS_BUILD_FOLDER="${BUILD_FOLDER}/rocm-deps"
[ -e "${ROCM_DEPS_BUILD_FOLDER}" ] || mkdir -p "${ROCM_DEPS_BUILD_FOLDER}"

OLD_BUILD_FOLDER="${BUILD_FOLDER}"
BUILD_FOLDER="${ROCM_DEPS_BUILD_FOLDER}"
cd "${ROCM_DEPS_BUILD_FOLDER}"

# ===============================================================================================
#                                       libX11
# ===============================================================================================
export PYTHONPATH=${INSTALL_DIR}/lib/python${PYTHON_VERSION}/site-packages:$PYTHONPATH
export_vars ${ROCM_DEPS_INSTALL_FOLDER}
configure_build https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.gz
autoreconf_build https://www.x.org/archive//individual/util/util-macros-1.19.3.tar.gz
configure_build https://xcb.freedesktop.org/dist/libpthread-stubs-0.1.tar.gz
autoreconf_build https://gitlab.freedesktop.org/xorg/lib/libxtrans/-/archive/xtrans-1.4.0/libxtrans-xtrans-1.4.0.tar.gz
autoreconf_build https://www.x.org/archive/individual/proto/xproto-7.0.31.tar.gz
autoreconf_build https://gitlab.freedesktop.org/xorg/proto/xextproto/-/archive/xextproto-7.3.0/xextproto-xextproto-7.3.0.tar.gz
autoreconf_build https://gitlab.freedesktop.org/xorg/proto/xcbproto/-/archive/xcb-proto-1.15/xcbproto-xcb-proto-1.15.tar.gz

# issues installing libXau 1.0.6, tried just configure install of 1.0.11 and that worked
#autoreconf_build https://www.x.org/releases/individual/lib/libXau-1.0.6.tar.gz
#autoreconf_build https://www.x.org/releases/individual/lib/libXau-1.0.11.tar.gz
configure_build https://www.x.org/releases/individual/lib/libXau-1.0.11.tar.gz

autoreconf_build https://gitlab.freedesktop.org/xorg/proto/inputproto/-/archive/inputproto-2.3.2/inputproto-inputproto-2.3.2.tar.gz

# issues installing libxcb but is already installed so why install it? Is slightly older version. 
# installation is complaining about macros but xorg macros 1.19 are installed here locally. What is missing?
#autoreconf_build https://gitlab.freedesktop.org/xorg/lib/libxcb/-/archive/libxcb-1.14/libxcb-libxcb-1.14.tar.gz
# configure_build https://gitlab.freedesktop.org/xorg/lib/libxcb/-/archive/libxcb-1.14/libxcb-libxcb-1.14.tar.gz

autoreconf_build https://gitlab.freedesktop.org/xorg/lib/libpciaccess/-/archive/libpciaccess-0.16/libpciaccess-libpciaccess-0.16.tar.gz

[ -e kbproto ] || run_command git clone https://gitlab.freedesktop.org/xorg/proto/kbproto
run_command cd kbproto
if [ -e rfs_installed ] &&  [ ${SKIP_INSTALLED} -eq 1 ]; then
  	echo "kbproto already installed. Skipping.."
else
    run_command git checkout kbproto-1.0.7
    run_command aclocal
    run_command autoreconf -if
    run_command ./configure --prefix="${INSTALL_DIR}"
    run_command make -j $NCORES install
    run_command touch rfs_installed
fi
autoreconf_build https://www.x.org/releases/individual/lib/libX11-1.6.8.tar.gz


# -----------------------------------------------------------------------------------------------
#                                          libffi
# -----------------------------------------------------------------------------------------------
configure_build https://github.com/libffi/libffi/releases/download/v3.4.3/libffi-3.4.3.tar.gz 

# -----------------------------------------------------------------------------------------------
#                                   OpenGL & OpenCL headers
# -----------------------------------------------------------------------------------------------
[ -e mesa ] || run_command git clone https://github.com/anholt/mesa.git
export_vars "${BUILD_FOLDER}/mesa"

# -----------------------------------------------------------------------------------------------
#                                    msgpack & fmt
# -----------------------------------------------------------------------------------------------

# Needed for rocBLAS
[ -e msgpack-c ] || run_command git clone -b cpp-3.0.1 https://github.com/msgpack/msgpack-c.git
cmake_install msgpack-c -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DMSGPACK_BUILD_TESTS=OFF -DMSGPACK_BUILD_EXAMPLES=OFF

# needed for rocsolver
[ -e fmt ] || run_command git clone -b6.1.2 https://github.com/fmtlib/fmt.git
cmake_install fmt -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DCMAKE_CXX_FLAGS=-fPIC

# now that we have msgpack, we can install all the others
run_command pip3 install --prefix=${INSTALL_DIR} msgpack pyaml

# -----------------------------------------------------------------------------------------------
#                                    libdrm
# -----------------------------------------------------------------------------------------------
wget_untar_cd https://github.com/mesonbuild/meson/releases/download/0.61.5/meson-0.61.5.tar.gz
export PATH="${BUILD_FOLDER}/meson-0.61.5:$PATH" # in order to use meson
if ! [ -e ninja ]; then
    run_command wget https://github.com/ninja-build/ninja/releases/download/v1.11.0/ninja-linux.zip
    run_command unzip ninja-linux.zip
fi


wget_untar_cd https://gitlab.freedesktop.org/mesa/drm/-/archive/libdrm-2.4.111/drm-libdrm-2.4.111.tar.gz
if [ -e rfs_installed ] &&  [ ${SKIP_INSTALLED} -eq 1 ]; then
  	echo "libdrm already installed. Skipping.."
else
    run_command  meson.py builddir --prefix="${INSTALL_DIR}"
    run_command ninja -C builddir -j $NCORES install
    run_command touch rfs_installed
fi
# -----------------------------------------------------------------------------------------------------
#                                         sqlite3
#------------------------------------------------------------------------------------------------------
configure_build https://www.sqlite.org/snapshot/sqlite-snapshot-202205121156.tar.gz


# -----------------------------------------------------------------------------------------------------
#                                          bzip2
#------------------------------------------------------------------------------------------------------
wget_untar_cd https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
if [ -e rfs_installed ] &&  [ ${SKIP_INSTALLED} -eq 1 ]; then
  	echo "bzip2 already installed. Skipping.."
else
    run_command make -j $NCORES install CFLAGS=-fPIC  PREFIX="${INSTALL_DIR}"
    run_command touch rfs_installed
fi
# -----------------------------------------------------------------------------------------------------
#                                          boost
#------------------------------------------------------------------------------------------------------
cd ${BUILD_FOLDER}
# Needed fo Tensile - exactly this version!
[ -e boost_1_79_0_rc1.tar.gz ] || wget https://boostorg.jfrog.io/artifactory/main/release/1.79.0/source/boost_1_79_0_rc1.tar.gz
[ -e boost_1_79_0 ] || tar xf boost_1_79_0_rc1.tar.gz
cd boost_1_79_0
BOOST_ROOT_DIR=`pwd`
if [ -e rfs_installed ] &&  [ ${SKIP_INSTALLED} -eq 1 ]; then
  	echo "Boost already installed. Skipping.."
else
    # the following is needed due to a bug in boost 1.72 installation process
    OLD_CPLUS_VAR=$CPLUS_INCLUDE_PATH
    export CPLUS_INCLUDE_PATH=""
    # this is a hacky way of making sure you use the correct compiler when building boost
    # what it will do is momentarily add an appropriate compiler to the path so boost's silly configure script is happy
    mkdir -p foobin
    OLD_PATH=$PATH
    export PATH=$(pwd)/foobin/:$PATH
    echo '#!/bin/bash' > $(pwd)/foobin/${ROCM_BASE_COMPILER_CXX_NAME}
    echo 'CC "$@"' >> $(pwd)/foobin/${ROCM_BASE_COMPILER_CXX_NAME}
    ( unset CPLUS_INCLUDE_PATH; ./bootstrap.sh --prefix="${INSTALL_DIR}" --with-toolset=${ROCM_BASE_COMPILER_TOOLSET})
    export CPLUS_INCLUDE_PATH=$OLD_CPLUS_VAR
    run_command ./b2 headers
    # why is the toolset hardcoded ???!!! 
    run_command ./b2 -j$NCORES cxxflags=-fPIC cflags=-fPIC install --with=all --prefix="${INSTALL_DIR}"
    # run_command ./b2 -j$NCORES cxxflags=-fPIC cflags=-fPIC install toolset=gcc --with=all --prefix="${INSTALL_DIR}"
    export PATH=${OLDPATH}
    rm -rf foobin/
    run_command touch "${BOOST_ROOT_DIR}/rfs_installed"
fi
# -----------------------------------------------------------------------------------------------------
#                                          gettext
#------------------------------------------------------------------------------------------------------
configure_build https://ftp.gnu.org/gnu/gettext/gettext-0.20.1.tar.gz

# -----------------------------------------------------------------------------------------------------
#                                          liblzma
# provided by xz
# required by elfutils
#------------------------------------------------------------------------------------------------------
configure_build https://tukaani.org/xz/xz-5.4.1.tar.gz

# -----------------------------------------------------------------------------------------------------
#                                          elfutils
#------------------------------------------------------------------------------------------------------
cd ${BUILD_FOLDER}
[ -e elfutils ] || run_command git clone git://sourceware.org/git/elfutils.git
run_command cd elfutils
if [ -e rfs_installed ] &&  [ ${SKIP_INSTALLED} -eq 1 ]; then
  	echo "elfutils already installed. Skipping.."
else
    run_command git checkout elfutils-0.187
    run_command autoreconf -i -f
    run_command ./configure LDFLAGS='' CFLAGS="" CXXFLAGS="" --enable-maintainer-mode --disable-libdebuginfod --disable-debuginfod --prefix="${INSTALL_DIR}"
    run_command make -j $NCORES install
    run_command touch "rfs_installed"
fi

# -----------------------------------------------------------------------------------------------------
#                                          gmplib
#------------------------------------------------------------------------------------------------------
cd ${BUILD_FOLDER}
[ -e gmp-6.2.1.tar.xz ] || run_command wget https://gmplib.org/download/gmp/gmp-6.2.1.tar.xz
[ -e gmp-6.2.1 ] || run_command tar -xf gmp-6.2.1.tar.xz
run_command cd ${BUILD_FOLDER}/gmp-6.2.1
if [ -e rfs_installed ] &&  [ ${SKIP_INSTALLED} -eq 1 ]; then
  	echo "gmp already installed. Skipping.."
else
    run_command ./configure --prefix=${INSTALL_DIR}
    run_command make -j $NCORES
    run_command make install
    run_command touch "rfs_installed"
fi


# -----------------------------------------------------------------------------------------------------
#                                          libexpat
#------------------------------------------------------------------------------------------------------
wget_untar_cd https://github.com/libexpat/libexpat/releases/download/R_2_4_8/expat-2.4.8.tar.gz
if [ -e rfs_installed ] &&  [ ${SKIP_INSTALLED} -eq 1 ]; then
  	echo "gmp already installed. Skipping.."
else
    mkdir build
    cd build
    run_command cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} ..
    run_command make -j $NCORES install
    run_command touch ../rfs_installed
fi


# needed for rocprofiler in/since ROCm 5.3.0
get_aqlprofiler() {
    if [ -e ${ROCM_INSTALL_DIR}/lib/libhsa-amd-aqlprofile64.so ]; then
        echo "AQL profiler precompiled library is already installed."
    else
        echo "Getting the AQL profiler precompiled library..."
        cd $BUILD_FOLDER
        run_command mkdir aqlprofiler
        AQL_FILENAME=hsa-amd-aqlprofile5.3.0_1.0.0.50300-63~22.04_amd64
        [ -e ${AQL_FILENAME} ] || run_command wget http://repo.radeon.com/rocm/apt/5.3/pool/main/h/hsa-amd-aqlprofile5.3.0/${AQL_FILENAME}.deb
        [ -e data.tar.xz ] || run_command ar x ${AQL_FILENAME}.deb
        [ -d opt ] || run_command tar xf data.tar.xz
        mkdir -p ${ROCM_INSTALL_DIR}/lib
        run_command cp -r opt/rocm-5.3.0/lib/* ${ROCM_INSTALL_DIR}/lib
        echo "AQL profiler library retrieved."
        cd $BUILD_FOLDER
    fi
}

get_aqlprofiler
run_command touch "${INSTALL_DIR}/.completed"
BUILD_FOLDER="${OLD_BUILD_FOLDER}"
