# utils.sh
# Utility sh functions to perform common and repetitive tasks.
# Author: Cristian Di Pietrantonio (cdipietrantonio{at}pawsey{dot}org{dot}au)
# License: see LICENSE file.



# Takes as a argument an absolute path to a directory and adds the include, lib, bin, etc.., 
# directories within it to the relevant build and runtime linux environment variables.
export_vars () {
    export LD_LIBRARY_PATH=$1/lib:$1/lib64:${LD_LIBRARY_PATH%:}
    export LIBRARY_PATH=$1/lib:$1/lib64:${LIBRARY_PATH%:}
    export PATH=$1/bin:${PATH%:}
    export CPATH=$1/include:$1/inc:${CPATH%:}
    export ACLOCAL_PATH=$1/share/aclocal:${ACLOCAL_PATH%:}
    export PKG_CONFIG_PATH=$1/lib/pkgconfig:$1/lib64/pkgconfig:$1/share/pkgconfig:${PKG_CONFIG_PATH%:}

    # the following is needed for compilation purposes
    #export CFLAGS="$CFLAGS -Wl,-rpath=$1/lib -Wl,-rpath=$1/lib64"
    #export CXXFLAGS="$CXXFLAGS -Wl,-rpath=$1/lib -Wl,-rpath=$1/lib64"
}


# Executes a bash command line, stopping the execution of the script if something goes wrong.
run_command () {
    echo "Running command $@"
    # All the following mess is due to the ';' present in some CMake parameters.
    # We need to put arguments to cmake into single quotes.
    string_to_eval=""
    for arg in $@;
    do
        string_to_eval="$string_to_eval '$arg'"
    done
    eval "$string_to_eval"
    if [ $? -ne 0 ]; then
        echo "Error running a command: $@"
           exit 1
    fi           
}


# Executes a cmake installation of the project specified as first argument, optionally using the cmake
# flags passed as further arguments.
cmake_install () {
    run_command cd "${BUILD_FOLDER}"
    PACKAGE_NAME="$1"
    SOURCE_DIR=".."
    if [ $# -eq 1 ]; then
        CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}"
    else
        CMAKE_FLAGS=""
        declare -i narg
        narg=0
        for arg in $@;
        do
            (( narg=narg + 1 ))
            if [ $narg -eq 1 ]; then continue; fi;
            CMAKE_FLAGS="$CMAKE_FLAGS $arg"
        done
    fi
    echo "Installing ${PACKAGE_NAME} .."
    cd "${PACKAGE_NAME}"
    if [ "${PACKAGE_NAME}" = "ROCR-Runtime" ] || [ "${PACKAGE_NAME}" = "atmi" ]; then
        run_command cd src
    elif [ "${PACKAGE_NAME}" = "ROCm-CompilerSupport" ]; then
        run_command cd lib/comgr
    elif [ "${PACKAGE_NAME}" = "llvm-project" ]; then
        SOURCE_DIR="../llvm"
    fi
    if [ -d build ] && [ $CLEAN_BUILD -eq 1 ]; then
        echo "Cleaning build directory.."
        rm -rf build;
    fi
    [ -d build ] || mkdir build 
    run_command cd build
    run_command cmake "${CMAKE_FLAGS}" "${SOURCE_DIR}"
    run_command make -j ${NCORES} install
    run_command cd "${BUILD_FOLDER}"
}

# download and untar an archive, then move into the extracted folder.
wget_untar_cd () {
    url=$1
    tarfile=${url##*/}
    folder=${tarfile%.tar.gz}
    if [ -z ${BUILD_FOLDER+x} ]; then BUILD_FOLDER="."; fi;
    cd ${BUILD_FOLDER}
    [ -e ${tarfile} ] || run_command wget "${url}"
    [ -e ${folder} ] || run_command tar xf "${tarfile}"
    run_command cd "$folder"
}

# run a configure build starting from a link to the tar.gz source distribution.
configure_build () {
    run_command cd ${BUILD_FOLDER}
    wget_untar_cd $1
    run_command ./configure --prefix="${INSTALL_DIR}"
    run_command make -j $NCORES install
    cd ${BUILD_FOLDER}
}


# run a autoreconf & configure build starting from a link to the tar.gz source distribution.
# useful mainly for the x11 packages
autoreconf_build () {
    run_command cd ${BUILD_FOLDER}
    wget_untar_cd $1
    run_command aclocal
    run_command autoreconf -if
    run_command ./configure --prefix="${INSTALL_DIR}"
    run_command make -j $NCORES install
    run_command cd ${BUILD_FOLDER}
}
