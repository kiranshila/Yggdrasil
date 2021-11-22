using BinaryBuilder, Pkg

name = "OpenMPI"
version = v"4.1.1"
sources = [
    ArchiveSource("https://download.open-mpi.org/release/open-mpi/v$(version.major).$(version.minor)/openmpi-$(version).tar.gz",
                  "d80b9219e80ea1f8bcfe5ad921bd9014285c4948c5965f4156a3831e60776444"),
    ArchiveSource("https://github.com/eschnett/MPIconstants/archive/refs/tags/v1.3.2.tar.gz",
                  "3437eb7913cf213de80cef4ade7d73f0b3adfe9eadabe993b923dc50a21bd65e"),
    DirectorySource("./bundled"),
]

script = raw"""
################################################################################
# Install OpenMPI
################################################################################

# Enter the funzone
cd ${WORKSPACE}/srcdir/openmpi-*

if [[ "${target}" == *-freebsd* ]]; then
    # Help compiler find `complib/cl_types.h`.
    export CPPFLAGS="-I/opt/${target}/${target}/sys-root/include/infiniband"
fi

FLAGS=()
FLAGS+=(--prefix=${prefix})
FLAGS+=(--build=${MACHTYPE})
FLAGS+=(--host=${target})
FLAGS+=(--enable-shared=yes)
FLAGS+=(--enable-static=no)
FLAGS+=(--without-cs-fs)
FLAGS+=(--enable-mpi-fortran=usempif08)
FLAGS+=(--with-cross=${WORKSPACE}/srcdir/${target})

if [[ "${target}" == *x86_64* || "${target}" == *powerpc64le* ]]; then
    FLAGS+=(--with-cuda=${prefix}/cuda)
    FLAGS+=(--with-ucx=${prefix}/ucx)
fi

./configure ${FLAGS[@]}

# Build the library
make -j${nproc}

# Install the library
make install

################################################################################
# Install MPIconstants
################################################################################

cd ${WORKSPACE}/srcdir/MPIconstants*
mkdir build
cd build

cmake \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_FIND_ROOT_PATH=${prefix} \
    -DCMAKE_INSTALL_PREFIX=${prefix} \
    -DBUILD_SHARED_LIBS=ON \
    -DMPI_C_COMPILER=cc \
    -DMPI_C_LIB_NAMES='mpi' \
    -DMPI_mpi_LIBRARY=${prefix}/lib/libmpi.${dlext} \
    ..

cmake --build . --config RelWithDebInfo --parallel $nproc
cmake --build . --config RelWithDebInfo --parallel $nproc --target install

################################################################################
# Install licenses
################################################################################

install_license $WORKSPACE/srcdir/openmpi*/LICENSE $WORKSPACE/srcdir/MPIconstants-*/LICENSE.md
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line.
#platforms = supported_platforms()
platforms = filter(p -> !Sys.iswindows(p) && !(arch(p) == "armv6l" && libc(p) == "glibc"), supported_platforms(; experimental=true))
platforms = expand_gfortran_versions(platforms)
    
products = [
    # OpenMPI
    LibraryProduct("libmpi", :libmpi),
    ExecutableProduct("mpiexec", :mpiexec),
    # MPIconstants
    LibraryProduct("libload_time_mpi_constants", :libload_time_mpi_constants),
    ExecutableProduct("generate_compile_time_mpi_constants", :generate_compile_time_mpi_constants),
]

cuda_version = v"11.2.0"
ucx_version = v"1.10.0"

dependencies = [
    Dependency("CompilerSupportLibraries_jll"),
    BuildDependency(PackageSpec(name="UCX_jll",version=ucx_version)),
    BuildDependency(PackageSpec(name="CUDA_full_jll", version=cuda_version)),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.6", preferred_gcc_version=v"5")
