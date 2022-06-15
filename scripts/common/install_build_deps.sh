# ============================================================================================================
#                                       BUILD ENVIRONMENT SETUP
# ============================================================================================================

BUILD_DEPS="${BUILD_FOLDER}/build-deps"
[ -d "${BUILD_DEPS}/bin" ] || mkdir -p "${BUILD_DEPS}/bin"
export_vars "${BUILD_DEPS}"

# we need "python" and "pip" executables
[ -e  ${BUILD_DEPS}/bin/python ] || \
    run_command ln -s `which python3` ${BUILD_DEPS}/bin/python;
[ -e  ${BUILD_DEPS}/bin/pip ] || \
    run_command ln -s `which pip3` ${BUILD_DEPS}/bin/pip;

# Always use the latest cmake. ROCMm depends heavily on latest CMake features, including HIP support.
if ! [ -f "${BUILD_DEPS}/bin/cmake" ]; then
    wget_untar_cd "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz"
    run_command ./configure --prefix="${BUILD_DEPS}"
    run_command make -j $NCORES
    run_command make install
fi

if ! [ -f "${BUILD_DEPS}/bin/repo" ]; then
    run_command curl https://storage.googleapis.com/git-repo-downloads/repo -o "${BUILD_DEPS}/bin/repo"
    run_command chmod a+x "${BUILD_DEPS}/bin/repo"
fi

export PYTHONPATH=${BUILD_DEPS}/pypackages/lib/python3.9/site-packages:$PYTHONPATH
pip3 install --prefix=${BUILD_DEPS}/pypackages cppheaderparser argparse virtualenv wheel
export PATH=${BUILD_DEPS}/pypackages/bin:$PATH