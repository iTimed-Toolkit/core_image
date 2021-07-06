# iTimed Toolkit

This is the repository containing the main development environment for the iTimed toolkit,
as discussed [here](https://eprint.iacr.org/2021/464). To make it easier for future researchers
to set up a development environment, we ship the toolkit as a self-contained Docker image. We
have two versions of the core image, which we both build from the same Dockerfile.

- *devel*: This is the full development image, containing all source code for all parts of the
   toolkit. Additionally, all necessary source code is built, and all build artifacts (as well
   as final images/programs) are kept in place. This enables fast development, without having
   to wait an hour for an initial compile. However, this image is quite large (>10GB).

- *default*: This image is built using a default, minimal configuration for Project Sandcastle.
   This image will successfully boot Linux on an iPhone 7, allowing for some basic exploration
   of the experimental environment. However, only the final images/programs are kept for this
   image. Build artifacts, as well as some source code, are removed in order to keep the image
   size small.

## Building

Both Docker images are automatically built using Github Actions. On a push to the repository,
the build system automatically builds the images and releases them as packages on the Github
Container Repository. This should extend to forks of this repository as well, allowing for
relatively minimal build enviroments on individual researcher hosts (although full CI builds
usually take about 6 hours). Of course, the Docker images can always be built locally by
cloning this repository and using `docker build --target <target> .`, where `<target>`
is one of `devel` or `default`.

## Patching

Talk about patches under patches directory.

## Usage

Talk about how to actually use these images and platforms -- USB passthrough, considerations,
etc

## Common changes

 - Linux kernel command line in arch/arm64/boot/dtx/hx/...

 - WiFi: due to changes in Apple's APFS structure, the Corellium APFS driver no longer succeeds in mounting the data portition. In order to get the WiFi firmware, gotta get it manually.
