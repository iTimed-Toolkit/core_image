FROM ubuntu as devel
WORKDIR "/root"

######################################
## Stage 1: Install needed packages ##
######################################

# These are needed for getting the checkra1n public key
# in the following step
RUN apt-get update && apt-get install -y gnupg ca-certificates

# Add checkra1n repository. Note that we manually install
# checkra1n later (to avoid pulling in GUI dependencies),
# but we still need this repository for ld64 and cctools-strip 
RUN echo 'deb https://assets.checkra.in/debian /' | \
    tee /etc/apt/sources.list.d/checkra1n.list &&   \
    apt-key adv --fetch-keys https://assets.checkra.in/debian/archive.key

# Install image dependencies
RUN apt-get update && apt-get install -y                            \
    # general                                                       \
    wget git build-essential usbutils                               \
    # sandcastle                                                    \
    libncurses-dev file cpio zip rsync bc python python3 libssl-dev \
    # pongo etc
    nano clang llvm libusb-1.0-0-dev xxd ld64 cctools-strip

# Get and install checkra1n -- update hash when selecting a new version
RUN export HASH=dac9968939ea6e6bfbdedeb41d7e2579c4711dc2c5083f91dced66ca397dc51d && \
    wget -q https://assets.checkra.in/downloads/linux/cli/x86_64/$HASH/checkra1n && \
    install -Dm 755 checkra1n /usr/local/bin/checkra1n && rm checkra1n

##################################
## Stage 2: Create a build user ##
##################################

RUN useradd -ms /bin/bash itimed
USER itimed
WORKDIR "/home/itimed"

#######################################################
## Stage 3: Get sources for various parts of toolkit ##
#######################################################

# Note that the directory layout of these is impotant. The
# platform makefiles under platforms/ assume this specific
# layout, so make sure to update those references too if
# updating this.

RUN mkdir -p sources && mkdir -p sources/sandcastle
RUN git clone --depth 1 --branch sandcastle-5.4 --single-branch \
    https://github.com/corellium/linux-sandcastle               \
    sources/sandcastle/linux-sandcastle

RUN git clone --depth 1 --branch sandcastle --single-branch     \
    https://github.com/corellium/sandcastle-buildroot           \
    sources/sandcastle/sandcastle-buildroot

RUN git clone --depth 1 --branch master --single-branch         \
    https://github.com/corellium/projectsandcastle              \
    sources/sandcastle/projectsandcastle

RUN git clone --depth 1 --branch master --single-branch         \
    https://github.com/checkra1n/pongoOS                        \
    sources/pongoOS

######################################
## Stage 4: Patch and build sources ##
######################################

COPY --chown=itimed ./patches ./patches
RUN cd ./patches ; ./apply_patches.sh
RUN rm -rf ./patches

COPY --chown=itimed ./platforms ./platforms
RUN make -C platforms/linux images

######################################
## Stage 5: Build the default image ##
######################################

FROM devel as default

RUN ./platforms/solidify_images.sh
RUN make -C platforms/linux source-clean
