# Takes as argument an absolute path to a directory and adds the include, lib, bin directories within it 
# to the build and runtime linux environment variables 
export_vars () {
    export LD_LIBRARY_PATH=$1/lib:$1/lib64:$LD_LIBRARY_PATH
    export LIBRARY_PATH=$1/lib:$1/lib64:$LIBRARY_PATH
    export PATH=$1/bin:$PATH
    export CPATH=$1/include:$1/inc:$CPATH
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
        CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}"
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
    [ -d build ] || mkdir build 
    run_command cd build
    run_command cmake "${CMAKE_FLAGS}" "${SOURCE_DIR}"
    run_command make -j ${NCORES} install
    run_command cd "${BUILD_FOLDER}"
}
