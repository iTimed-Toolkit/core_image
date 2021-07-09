FROM ubuntu AS clean
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
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1          \
    apt-key adv --fetch-keys https://assets.checkra.in/debian/archive.key

# Install image dependencies
RUN apt-get update && apt-get install -y                            \
    # general                                                       \
    sudo wget git build-essential usbutils                          \
    # sandcastle                                                    \
    libncurses-dev file cpio zip rsync bc python python3 libssl-dev \
    # pongo etc                                                     \
    nano clang llvm libusb-1.0-0-dev xxd ld64 cctools-strip

# Get and install checkra1n -- update hash when selecting a new version
RUN export HASH=dac9968939ea6e6bfbdedeb41d7e2579c4711dc2c5083f91dced66ca397dc51d && \
    wget -q https://assets.checkra.in/downloads/linux/cli/x86_64/$HASH/checkra1n && \
    install -Dm 755 checkra1n /usr/local/bin/checkra1n && rm checkra1n

##################################
## Stage 2: Create a build user ##
##################################

RUN useradd -ms /bin/bash itimed -G sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER itimed
WORKDIR "/home/itimed"

#######################################################
## Stage 3: Get sources for various parts of toolkit ##
#######################################################

# Note that the directory layout of these is impotant. The
# platform makefiles under platforms/ assume this specific
# layout, so make sure to update those references too if
# updating this.

RUN mkdir -p sources/sandcastle
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

COPY --chown=itimed ./platforms ./platforms
COPY --chown=itimed ./env.sh ./env.sh
ENV ENVFILE=/home/itimed/env.sh

COPY --chown=itimed ./overlay ./overlay
RUN . "$ENVFILE" && ./overlay/apply_overlay.sh && rm -rf ./overlay
COPY --chown=itimed ./patches ./patches
RUN . "$ENVFILE" && ./patches/apply_patches.sh && rm -rf ./patches

FROM clean AS devel
RUN . "$ENVFILE" && make -C platforms/linux images

FROM clean AS default
COPY --from=devel /home/itimed/platforms/linux/images/* \
                    /home/itimed/platforms/linux/images/
COPY --from=devel /home/itimed/sources/sandcastle/sandcastle-buildroot/output/host/ \
                    /usr/local/
