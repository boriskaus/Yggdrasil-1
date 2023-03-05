# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "GMT"
version = v"6.4.0"

GSHHG_VERSION="2.3.7"
DCW_VERSION="2.1.1"

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/GenericMappingTools/gmt", 
    "19413d486888ebdc3c01aeed3707bcc88eb727df"),

    ArchiveSource("https://github.com/GenericMappingTools/gshhg-gmt/releases/download/$GSHHG_VERSION/gshhg-gmt-$GSHHG_VERSION.tar.gz",
        "9bb1a956fca0718c083bef842e625797535a00ce81f175df08b042c2a92cfe7f"),

    ArchiveSource("https://github.com/GenericMappingTools/dcw-gmt/releases/download/$DCW_VERSION/dcw-gmt-$DCW_VERSION.tar.gz",
        "d4e208dca88fbf42cba1bb440fbd96ea2f932185c86001f327ed0c7b65d27af1")
]

# Bash recipe for building across all platforms
script = raw"""

GSHHG_VERSION_numeric=2.3.7     
GSSHG="gshhg-gmt-2.3.7"
DCW="dcw-gmt-2.1.1"
EXT="tar.gz"

cd $WORKSPACE/srcdir
cd gmt
mkdir build
cd build/

cmake -DCMAKE_INSTALL_PREFIX=${prefix} \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_BUILD_TYPE=Release \
    -DHAVE_QSORT_R_GLIBC=False \
    -DHAVE___BUILTIN_BSWAP16=False \
    -DHAVE___BUILTIN_BSWAP32=False \
    -DHAVE___BUILTIN_BSWAP64=False \
    -DGMT_ENABLE_OPENMP=True \
    -DGSHHG_PATH=/workspace/srcdir/${GSSHG} \
    -DGSHHG_VERSION=${GSHHG_VERSION_numeric} \
    -DDCW_PATH=/workspace/srcdir/${DCW} \
    .. 
make -j${nproc} 
make install 

if [[ "${target}" == *-mingw* ]]; then
    install -Dvm 755 /workspace/destdir/bin/gmt.${dlext} "${libdir}/libgmt.${dlext}"
    install -Dvm 755 /workspace/destdir/bin/postscriptlight.${dlext} "${libdir}/libpostscriptlight.${dlext}"

    # note that this removes the *.dll: 
    install -Dvm 755 /workspace/destdir/bin/gmt_plugins/supplements.* "${libdir}/supplements"

else
    # supplements is an *.so file on *ix systems; which is installed with (note that this removes the extension):
    install -Dvm 755 /workspace/destdir/lib/gmt/plugins/supplements.* "${libdir}/supplements"

fi

"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Platform("x86_64", "linux"; libc = "glibc"),
    Platform("aarch64", "linux"; libc = "glibc"),
    Platform("x86_64", "macos"; ),
    Platform("aarch64", "macos"; ),
    Platform("x86_64", "windows"; ),
    Platform("i686", "windows"; ),
]


# The products that we will ensure are always built
products = [
    LibraryProduct("libpostscriptlight", :libpostscriptlight),
    LibraryProduct("libgmt", :libgmt),
    ExecutableProduct("gmt", :gmt),
    FileProduct("bin/supplements", :supplements)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency(PackageSpec(name="LibCURL_jll", uuid="deac9b47-8bc7-5906-a0fe-35ac56dc84c0"); compat="7.73.0")
    Dependency("NetCDF_jll", compat="400.702.402")
    Dependency(PackageSpec(name="GDAL_jll", uuid="a7073274-a066-55f0-b90d-d619367d196c"))
    Dependency(PackageSpec(name="FFTW_jll", uuid="f5851436-0d7a-5f13-b9de-f02708fd171a"))
    Dependency(PackageSpec(name="PCRE_jll", uuid="2f80f16e-611a-54ab-bc61-aa92de5b98fc"))
    Dependency(PackageSpec(name="LAPACK32_jll", uuid="17f450c3-bd24-55df-bb84-8c51b4b939e3"))
    Dependency(PackageSpec(name="OpenBLAS32_jll", uuid="656ef2d0-ae68-5445-9ca0-591084a874a2"))
    Dependency(PackageSpec(name="FFMPEG_jll", uuid="b22a6f82-2f65-5046-a5b2-351ab43fb4e5"))
    Dependency(PackageSpec(name="Glib_jll", uuid="7746bdde-850d-59dc-9ae8-88ece973131d"))
    Dependency(PackageSpec(name="Ghostscript_jll", uuid="61579ee1-b43e-5ca0-a5da-69d92c66a64b"))
    Dependency(PackageSpec(name="CompilerSupportLibraries_jll", uuid="e66e0078-7015-5450-92f7-15fbd957f2ae"); platforms=filter(!Sys.isbsd, platforms))
    Dependency(PackageSpec(name="LLVMOpenMP_jll", uuid="1d63c593-3942-5779-bab2-d838dc0a180e"); platforms=filter(Sys.isbsd, platforms))
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6", preferred_gcc_version = v"7.1.0")
