# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, BinaryBuilderBase, Pkg

name = "crun"
version = v"1.7.1"

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/containers/crun",
              "0356bf4aff9a133d655dc13b1d9ac9424706cac4")
]

# Bash recipe for building across all platforms
script = raw"""
# check if we need to use a more recent glibc
if [[ -f "$prefix/usr/include/sched.h" ]]; then
    GLIBC_ARTIFACT_DIR=$(dirname $(dirname $(dirname $(realpath $prefix/usr/include/sched.h))))
    rsync --archive ${GLIBC_ARTIFACT_DIR}/ /opt/${target}/${target}/sys-root/
fi

cd crun
install_license COPYING

./autogen.sh
./configure --prefix=${prefix} --build=${MACHTYPE} --host=${target} \
            --disable-criu # missing JLL
make -j${nproc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()
filter!(Sys.islinux, platforms)
filter!(p -> libc(p) == "glibc", platforms)

# some platforms need a newer glibc, because the default one is too old
glibc_platforms = filter(platforms) do p
    libc(p) == "glibc" && proc_family(p) in ["intel", "power"]
end

# The products that we will ensure are always built
products = [
    ExecutableProduct("crun", :crun)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("YAJL_jll"),
    Dependency("libcap_jll"),
    Dependency("systemd_jll"),
    Dependency("libseccomp_jll"),

    # crun needs glibc >2.14
    BuildDependency(PackageSpec(name = "Glibc_jll", version = v"2.17");
                    platforms=glibc_platforms),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.6", preferred_gcc_version=v"7")