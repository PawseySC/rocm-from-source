#!/bin/sh

# The libX11 dependency is quite complex, so it deserves its own script.

export PATH="${BUILD_FOLDER}/meson-0.61.5:$PATH" # in order to use meson
run_command cd ${BUILD_FOLDER}/libtool-2.4.6
run_command ./configure --prefix="${BUILD_FOLDER}/build-deps"
run_command make -j $NCORES install

run_command cd "${BUILD_FOLDER}/util-macros-1.19.3"
run_command ./configure --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install

export ACLOCAL_PATH="${ROCM_INSTALL_DIR}/share/aclocal"
export ACLOCAL_PATH="${BUILD_FOLDER}/build-deps/share/libtool:${ACLOCAL_PATH}"
run_command cd "${BUILD_FOLDER}/libpthread-stubs-0.1"
run_command ./configure --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install

wget https://www.x.org/releases/individual/lib/xtrans-1.4.0.tar.gz
tar xvfz xtrans-1.4.0.tar.gz
cd xtrans-1.4.0
./configure --prefix=$ROCM_INSTALL_DIR
make
make install

run_command cd "${BUILD_FOLDER}/libxtrans-xtrans-1.4.0"
run_command ./autogen.sh
run_command ./configure --prefix=${ROCM_INSTALL_DIR}
run_command make
run_command install

run_command cd "${BUILD_FOLDER}/xproto-7.0.31"
run_command ./configure --prefix=${ROCM_INSTALL_DIR}
run_command make -j $NCORES install

run_command wget https://gitlab.freedesktop.org/xorg/proto/xextproto/-/archive/xextproto-7.3.0/xextproto-xextproto-7.3.0.tar.gz
run_command tar xf xextproto-xextproto-7.3.0.tar.gz
run_command cd xextproto-xextproto-7.3.0
run_command ./autogen.sh
run_command ./configure --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install


run_command wget https://gitlab.freedesktop.org/xorg/proto/xcbproto/-/archive/xcb-proto-1.15/xcbproto-xcb-proto-1.15.tar.gz
run_command tar xf xcbproto-xcb-proto-1.15.tar.gz
run_command cd ${BUILD_FOLDER}/xcbproto-xcb-proto-1.15
run_command aclocal
run_command autoreconf -if
run_command ./configure --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install

run_command wget http://www.x.org/releases/individual/lib/libXau-1.0.6.tar.bz2
run_command tar xf libXau-1.0.6.tar.bz2
run_command cd ${BUILD_FOLDER}/libXau-1.0.6
run_command aclocal
run_command autoreconf -if
run_command ./configure --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install


run_command wget https://gitlab.freedesktop.org/xorg/proto/inputproto/-/archive/inputproto-2.3.2/inputproto-inputproto-2.3.2.tar.gz
run_command tar xf inputproto-inputproto-2.3.2.tar.gz
run_command cd ${BUILD_FOLDER}/inputproto-inputproto-2.3.2
run_command aclocal
run_command autoreconf -if
run_command ./configure --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install

export PYTHONPATH=/software/projects/pawsey0001/cdipietrantonio/mulan-stuff/rocm-dev2/lib/python3.9/site-packages:$PYTHONPATH
run_command wget https://gitlab.freedesktop.org/xorg/lib/libxcb/-/archive/libxcb-1.14/libxcb-libxcb-1.14.tar.gz
run_command tar xf libxcb-libxcb-1.14.tar.gz
run_command cd ${BUILD_FOLDER}/libxcb-libxcb-1.14
run_command aclocal
run_command autoreconf -if
run_command ./configure --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install

run_command git clone https://gitlab.freedesktop.org/xorg/proto/kbproto
run_command cd kbproto
run_command git checkout kbproto-1.0.7
run_command aclocal
run_command autoreconf -if
run_command ./configure --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install

run_command cd "${BUILD_FOLDER}/libX11-1.6.8"
run_command ./configure --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install
