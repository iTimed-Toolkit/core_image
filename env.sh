# Important globals
export PROJECT_ROOT=/home/itimed
export PLATFORM_ROOT=$PROJECT_ROOT/platforms/linux

# Sandcastle
export SANDCASTLE_ROOT=$PROJECT_ROOT/sources/sandcastle
export SANDCASTLE_BUILD_ROOT=$SANDCASTLE_ROOT/sandcastle-buildroot
export SANDCASTLE_LOAD_ROOT=$SANDCASTLE_ROOT/projectsandcastle/loader
export KERNEL_ROOT=$SANDCASTLE_ROOT/linux-sandcastle

# Pongo
export PONGO_ROOT=$PROJECT_ROOT/sources/pongoOS

export PATH=$SANDCASTLE_BUILD_ROOT/output/host/bin/:$PATH
