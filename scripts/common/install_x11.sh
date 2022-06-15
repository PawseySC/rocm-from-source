#!/bin/sh

# The libX11 dependency is quite complex, so it deserves its own script.

if [ -z ${ROCM_INSTALL_DIR+x} ] || [ -z ${BUILD_FOLDER+x} ]; then
    echo "'install_x11.sh': one of the input variables is not set."
    exit 1
fi
INSTALL_DIR=${ROCM_INSTALL_DIR}
export_vars ${INSTALL_DIR}
X11_BUILD_FOLDER="${BUILD_FOLDER}/X11"
export PYTHONPATH=${INSTALL_DIR}/lib/python3.9/site-packages:$PYTHONPATH

[ -d ${X11_BUILD_FOLDER} ] || run_command mkdir -p ${X11_BUILD_FOLDER}

build_x11_package() {
    run_command cd ${X11_BUILD_FOLDER}
    url=$1
    tarfile=${url##*/}
    folder=${tarfile%.tar.gz}
    [ -e ${tarfile} ] || run_command wget "${url}"
    [ -e ${folder} ] || run_command tar xf "${tarfile}"
    run_command cd ${folder}
    run_command aclocal
    run_command autoreconf -if
    run_command ./configure --prefix="${INSTALL_DIR}"
    run_command make -j $NCORES install
}


# build the dependencies
configure_build https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.gz
build_x11_package https://www.x.org/archive//individual/util/util-macros-1.19.3.tar.gz
configure_build https://xcb.freedesktop.org/dist/libpthread-stubs-0.1.tar.gz

build_x11_package https://gitlab.freedesktop.org/xorg/lib/libxtrans/-/archive/xtrans-1.4.0/libxtrans-xtrans-1.4.0.tar.gz
build_x11_package https://www.x.org/archive/individual/proto/xproto-7.0.31.tar.gz
build_x11_package https://gitlab.freedesktop.org/xorg/proto/xextproto/-/archive/xextproto-7.3.0/xextproto-xextproto-7.3.0.tar.gz


build_x11_package https://gitlab.freedesktop.org/xorg/proto/xcbproto/-/archive/xcb-proto-1.15/xcbproto-xcb-proto-1.15.tar.gz
build_x11_package https://www.x.org/releases/individual/lib/libXau-1.0.6.tar.gz
build_x11_package https://gitlab.freedesktop.org/xorg/proto/inputproto/-/archive/inputproto-2.3.2/inputproto-inputproto-2.3.2.tar.gz
build_x11_package https://gitlab.freedesktop.org/xorg/lib/libxcb/-/archive/libxcb-1.14/libxcb-libxcb-1.14.tar.gz

cd ${X11_BUILD_FOLDER}
[ -e kbproto ] || run_command git clone https://gitlab.freedesktop.org/xorg/proto/kbproto
run_command cd kbproto
run_command git checkout kbproto-1.0.7
run_command aclocal
run_command autoreconf -if
run_command ./configure --prefix="${INSTALL_DIR}"
run_command make -j $NCORES install

build_x11_package https://www.x.org/releases/individual/lib/libX11-1.6.8.tar.gz