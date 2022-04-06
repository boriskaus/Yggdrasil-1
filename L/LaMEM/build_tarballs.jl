# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "LaMEM"
version = v"1.1.0"

# Collection of sources required to complete build
sources = [
    GitSource("https://bitbucket.org/bkaus/lamem.git", 
    "40c8582c2dce42876d7f3d787aa0d03c253447e3")
]

# Bash recipe for building across all platforms
script = raw"""

# Create required directories
mkdir $WORKSPACE/srcdir/lamem/bin
mkdir $WORKSPACE/srcdir/lamem/bin/opt
mkdir $WORKSPACE/srcdir/lamem/dep
mkdir $WORKSPACE/srcdir/lamem/dep/opt
mkdir $WORKSPACE/srcdir/lamem/lib
mkdir $WORKSPACE/srcdir/lamem/lib/opt

cd $WORKSPACE/srcdir/lamem/src
export PETSC_OPT=${libdir}/petsc/double_real_Int32/
ln -s  ${PETSC_OPT}/lib/libpetsc_double_real_Int32.${dlext} ${PETSC_OPT}/lib/libpetsc.${dlext}
make mode=opt all -j${nproc}

# compile dynamic library
make mode=opt dylib -j${nproc}

cd  $WORKSPACE/srcdir/lamem/bin/opt

# On some windows versions it automatically puts the .exe extension; on others not. 
# This deals with that
if [[ -f LaMEM ]]
then
    mv LaMEM LaMEM${exeext}
fi

cp LaMEM${exeext} $WORKSPACE/srcdir/lamem/
cp LaMEM${exeext} $WORKSPACE/srcdir
cd $WORKSPACE/srcdir/lamem

# Install binaries
install -Dvm 755 LaMEM* "${bindir}/LaMEM${exeext}"
install -vm 644 src/*.h "${includedir}"
install -Dvm 755 lib/opt/LaMEMLib.dylib "${libdir}/LaMEMLib.${dlext}"

# Install license
install_license LICENSE

exit
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = expand_gfortran_versions(supported_platforms(exclude=[Platform("i686", "windows"),
                                                                  Platform("i686", "linux"; libc = "musl")]))

# The products that we will ensure are always built
products = [
    ExecutableProduct("LaMEM", :LaMEM)
    LibraryProduct("LaMEMLib", :LaMEMLib)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency(PackageSpec(name="PETSc_jll", uuid="8fa3689e-f0b9-5420-9873-adf6ccf46f2d")),
    Dependency("MPICH_jll"; platforms=filter(!Sys.iswindows, platforms)),
    Dependency("MicrosoftMPI_jll"; platforms=filter(Sys.iswindows, platforms)),
    Dependency("CompilerSupportLibraries_jll")
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6", preferred_gcc_version = v"10.2.0")
