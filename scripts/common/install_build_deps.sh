# ============================================================================================================
#                                       BUILD ENVIRONMENT SETUP
# ============================================================================================================

BUILD_DEPS_FOLDER="${BUILD_FOLDER}/build-deps"
[ -d "${BUILD_DEPS_FOLDER}/bin" ] || mkdir -p "${BUILD_DEPS_FOLDER}/bin"
export_vars "${BUILD_DEPS_FOLDER}"

# we need "python" and "pip" executables
[ -e  ${BUILD_DEPS_FOLDER}/bin/python ] || \
    run_command ln -s `which python3` ${BUILD_DEPS_FOLDER}/bin/python;
[ -e  ${BUILD_DEPS_FOLDER}/bin/pip ] || \
    run_command ln -s `which pip3` ${BUILD_DEPS_FOLDER}/bin/pip;
[ -e ${BUILD_DEPS_FOLDER}/bin/cc ] || \
    run_command ln -sL `which gcc` ${BUILD_DEPS_FOLDER}/bin/cc;
[ -e ${BUILD_DEPS_FOLDER}/bin/CC ] || \
    run_command ln -sL `which g++` ${BUILD_DEPS_FOLDER}/bin/CC;
# Always use the latest cmake. ROCm depends heavily on latest CMake features, including HIP support.
if ! [ -f "${BUILD_DEPS_FOLDER}/bin/cmake" ]; then
    wget_untar_cd "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz"
    run_command ./configure --prefix="${BUILD_DEPS_FOLDER}"
    run_command make -j $NCORES
    run_command make install
fi

if ! [ -f "${BUILD_DEPS_FOLDER}/bin/repo" ]; then
    run_command curl https://storage.googleapis.com/git-repo-downloads/repo -o "${BUILD_DEPS_FOLDER}/bin/repo"
    run_command chmod a+x "${BUILD_DEPS_FOLDER}/bin/repo"
fi

export PATH=${BUILD_DEPS_FOLDER}/pypackages/bin:$PATH
export PYTHONPATH=${BUILD_DEPS_FOLDER}/pypackages/lib/python${PYTHON_VERSION}/site-packages:$PYTHONPATH
pip3 install --prefix=${BUILD_DEPS_FOLDER}/pypackages cppheaderparser argparse virtualenv wheel lit
