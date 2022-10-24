# ============================================================================================================
#                                       BUILD ENVIRONMENT SETUP
# ============================================================================================================

BUILD_DEPS_FOLDER="${BUILD_FOLDER}/build-deps"
cd ${BUILD_FOLDER}

[ -d "${BUILD_DEPS_FOLDER}/bin" ] || mkdir -p "${BUILD_DEPS_FOLDER}/bin"
export_vars "${BUILD_DEPS_FOLDER}"

# we need "python" and "pip" executables
[ -e ${BUILD_DEPS_FOLDER}/bin/python ] || \
    run_command ln -s `which python3` ${BUILD_DEPS_FOLDER}/bin/python;
[ -e ${BUILD_DEPS_FOLDER}/bin/pip ] || \
    run_command ln -s `which pip3` ${BUILD_DEPS_FOLDER}/bin/pip;

# Install git-lfs if needed
program_exists git-lfs

if [ $PROGRAM_EXISTS -eq 0 ]; then
    [ -e git-lfs-linux-amd64-v3.2.0.tar.gz ] || \
        run_command wget https://github.com/git-lfs/git-lfs/releases/download/v3.2.0/git-lfs-linux-amd64-v3.2.0.tar.gz
    [ -d git-lfs-3.2.0 ] || \
        run_command tar xf git-lfs-linux-amd64-v3.2.0.tar.gz
    run_command cp git-lfs-3.2.0/git-lfs ${BUILD_DEPS_FOLDER}/bin
fi

# Always use the latest cmake. ROCm depends heavily on latest CMake features, including HIP support.
program_exists cmake
CMAKE_AVAIL=0
if [ "$PROGRAM_EXISTS" = "1" ]; then 
    CMAKE_AVAIL=$(VER=`cmake --version | grep -oE "([0-9]+\.[0-9]+)"` && echo "$VER >= 3.23" | bc -l)
    if [ $? -ne 0 ]; then
        echo "Error while retrieving the cmake version."
        exit 1
    fi
fi

if [ "$CMAKE_AVAIL" = "0" ]; then
    wget_untar_cd "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz"
    run_command ./configure --prefix="${BUILD_DEPS_FOLDER}"
    run_command make -j $NCORES
    run_command make install
else
    echo "A suitable version of CMake is present, no need to build it from source."
fi

if ! [ -f "${BUILD_DEPS_FOLDER}/bin/repo" ]; then
    run_command curl https://storage.googleapis.com/git-repo-downloads/repo -o "${BUILD_DEPS_FOLDER}/bin/repo"
    run_command chmod a+x "${BUILD_DEPS_FOLDER}/bin/repo"
fi

export PATH=${BUILD_DEPS_FOLDER}/pypackages/bin:$PATH
export PYTHONPATH=${BUILD_DEPS_FOLDER}/pypackages/lib/python${PYTHON_VERSION}/site-packages:$PYTHONPATH
run_command pip3 install --prefix=${BUILD_DEPS_FOLDER}/pypackages cppheaderparser argparse virtualenv wheel lit
