FROM ubuntu:focal-20220113

# Utilities:
# build-essential, cmake, curl, git, jq
#
# Build Requirements:
# libclang-dev, libprotobuf-dev, libpq-dev, libssl1.1,
# libssl-dev, llvm, llvm-dev, pkg-config, protobuf-compiler
#
# Needed for GHA cache actions:
# zstd
RUN  ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime\
  && apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y \
     build-essential \
     clang \
     cmake \
     curl \
     git \
     jq \
     libclang-dev \
     libprotobuf-dev \
     libpq-dev \
     libssl1.1 \
     libssl-dev \
     llvm \
     llvm-dev \
     pkg-config \
     protobuf-compiler \
     zstd \
  && apt-get clean \
  && rm -r /var/lib/apt/lists

SHELL ["/bin/bash", "-c"]
# Install SGX

ARG SGX_URL=https://download.01.org/intel-sgx/sgx-linux/2.15/distro/ubuntu20.04-server/sgx_linux_x64_sdk_2.15.100.3.bin
RUN  curl -o sgx.bin "${SGX_URL}" \
  && chmod +x ./sgx.bin \
  && ./sgx.bin --prefix=/opt/intel \
  && rm ./sgx.bin

ENV SGX_SDK=/opt/intel/sgxsdk
ENV PATH=/opt/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/intel/sgxsdk/bin:/opt/intel/sgxsdk/bin/x64
ENV PKG_CONFIG_PATH=/opt/intel/sgxsdk/pkgconfig
ENV LD_LIBRARY_PATH=/opt/intel/sgxsdk/sdk_libs

# Github actions overwrites the runtime home directory, so we need to install in a global directory.
ENV RUSTUP_HOME=/opt/rustup
ENV CARGO_HOME=/opt/cargo
RUN  mkdir -p ${RUSTUP_HOME} \
  && mkdir -p ${CARGO_HOME}

# Install rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly-2021-07-21
RUN rustup toolchain install nightly-2022-01-10
