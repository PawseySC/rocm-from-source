# ============================================================================================================
#                                       BUILD ENVIRONMENT SETUP
# ============================================================================================================

BUILD_DEPS_FOLDER="${BUILD_FOLDER}/build-deps"

[ -d "${BUILD_DEPS_FOLDER}/bin" ] || mkdir -p "${BUILD_DEPS_FOLDER}/bin"
export_vars "${BUILD_DEPS_FOLDER}"

OLD_BUILD_FOLDER="${BUILD_FOLDER}"
BUILD_FOLDER="${BUILD_DEPS_FOLDER}"
INSTALL_DIR="$BUILD_DEPS_FOLDER"

cd ${BUILD_FOLDER}

# we need "python" and "pip" executables
[ -e ${BUILD_DEPS_FOLDER}/bin/python ] || \
    run_command ln -s `which python3` ${BUILD_DEPS_FOLDER}/bin/python;
[ -e ${BUILD_DEPS_FOLDER}/bin/pip ] || \
    run_command ln -s `which pip3` ${BUILD_DEPS_FOLDER}/bin/pip;
if [ "${COMPILER_BINDIR+x}" = "x" ] && [ ${INSTALL_ON_SUPERCOMPUTER} -eq 1 ] && ! [ -e ${BUILD_DEPS_FOLDER}/bin/gcc ]; then
   run_command ln -s "${COMPILER_BINDIR}/gcc" "${BUILD_DEPS_FOLDER}/bin/gcc";
fi
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
CMAKE_VERSION=3.24.2
program_exists cmake
CMAKE_AVAIL=0
if [ "$PROGRAM_EXISTS" = "1" ]; then 
    CMAKE_AVAIL=$(VER=`cmake --version | grep -oE "([0-9]+\.[0-9]+)"` && echo "$VER 3.23" | awk '{if ($1 >= $2) print 1; else print 0}')
    if [ $? -ne 0 ]; then
        echo "Error while retrieving the cmake version, building from scratch."
        CMAKE_AVAIL=0
    fi
fi

# makeinfo
echo "#!/bin/bash
exit 0" > ${BUILD_DEPS_FOLDER}/bin/makeinfo
run_command chmod 0777  ${BUILD_DEPS_FOLDER}/bin/makeinfo

if [ "$CMAKE_AVAIL" = "0" ]; then
    configure_build "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz"
else
    echo "A suitable version of CMake is present, no need to build it from source."
fi

if ! [ -f "${BUILD_DEPS_FOLDER}/bin/repo" ]; then
    run_command curl https://storage.googleapis.com/git-repo-downloads/repo -o "${BUILD_DEPS_FOLDER}/bin/repo"
    run_command chmod a+x "${BUILD_DEPS_FOLDER}/bin/repo"
fi

export PATH=${BUILD_DEPS_FOLDER}/pypackages/bin:$PATH
export PYTHONPATH=${BUILD_DEPS_FOLDER}/pypackages/lib/python${PYTHON_VERSION}/site-packages:$PYTHONPATH
python3 -c 'import CppHeaderParser'
PYPACKAGES_INSTALLED=$?
if [ ${PYPACKAGES_INSTALLED} -ne 0 ]; then
    run_command pip3 install --prefix=${BUILD_DEPS_FOLDER}/pypackages cppheaderparser argparse virtualenv wheel lit
fi
BUILD_FOLDER="${OLD_BUILD_FOLDER}"
