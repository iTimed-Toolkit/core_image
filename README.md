# iTimed Toolkit

This is the repository containing the main development environment for the iTimed toolkit,
as discussed [here](https://eprint.iacr.org/2021/464). To make it easier for future researchers
to set up a development environment, we ship the toolkit as a self-contained Docker image. We
have three versions of the core image, which we all build from the same Dockerfile.

- *clean*: This is a starting image containing all downloaded (and patched, see [here](#patching))
   source code for all parts of the    toolkit. It can be built by typing `make images` in any
   of the `platform/*` subdirectories -- be aware, however, that a full build from scratch can
   take a significant amount of time, memory, and CPU cycles.

- *devel*: This is the full development image, containing all source code for all parts of the
   toolkit. Additionally, all necessary source code is prebuilt, and all build artifacts (as well
   as final images/programs) are kept in place. This enables fast development, without having
   to wait an hour for an initial compile. However, this image is quite large (>10GB) so it is
   heftier to download.

- *default*: This image is built using a default, minimal configuration for Project Sandcastle.
   This image will successfully boot Linux on an iPhone 7, allowing for some basic exploration
   of the experimental environment. However, only the final images/programs are kept for this
   image. Intermediate build artifacts are removed in order to keep the image size small.

## Building

Docker images are automatically built using Github Actions. On a push to the repository,
the build system automatically builds the images and releases them as packages on the Github
Container Repository. This should extend to forks of this repository as well, allowing for
relatively minimal build enviroments on individual researcher hosts (although full CI builds
usually take about 6 hours). Of course, the Docker images can always be built locally by
cloning this repository and using `docker build --target <target> .`, where `<target>`
is one of `clean`, `devel`, or `default`.

## Patching {#patching}

Talk about patches under patches directory.

## Usage

Talk about how to actually use these images and platforms -- USB passthrough, considerations,
etc

`docker run --privileged -v /dev/bus/usb/:/dev/bus/usb/ -it core_image`

## Connecting

Three methods in order of complexity: USB gadget interface, serial cable, WiFi. For each of
these, we can use the default login of `root` with password `alpine`.

### USB gadget
The USB gadget interface is enabled by default and should bring up a new network interface
on your host machine when booting into Project Sandcastle (on mine, its `enp0s20f0u1u1`).
You'll want to reconfigure any NetworkManager or analogue to not manage this interface --
for me, adding these lines to my `/etc/NetworkManager/NetworkManager.conf` worked:

```
[main]
plugins=keyfile

[keyfile]
unmanaged-devices=interface-name:enp0s20f0u1u1
```

Then, you need to set the IP address for this interface. On my Linux system, doing the
following worked for me. Note that the specific IP address is configured in
`sources/sandcastle/sandcastle-buildroot/sandcastle-overlay/etc/network/intefaces` so
you can change this -- by default, though, you can just use `172.16.1.2/24`.

```
sudo ip addr add 172.16.1.2/24 dev enp0s20f0u1u1
```

### Serial

Todo

### WiFi

Does NOT work by default, but explain series of steps for making it work

## Common changes

 - Linux kernel command line in arch/arm64/boot/dtx/hx/...

 - WiFi: due to changes in Apple's APFS structure, the Corellium APFS driver no longer succeeds in mounting the data portition. In order to get the WiFi firmware, gotta get it manually.
