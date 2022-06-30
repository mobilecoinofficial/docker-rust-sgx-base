# Copyright (c) 2022 MobileCoin Inc.

FROM ubuntu:focal-20220426 as rust-sgx-base

SHELL ["/bin/bash", "-c"]

# Utilities:
# build-essential, cmake, curl, git, jq
#
# Build Requirements:
# libclang-dev, libprotobuf-dev, libpq-dev, libssl1.1,
# libssl-dev, llvm, llvm-dev, pkg-config, protobuf-compiler
#
# Needed for GHA cache actions:
# zstd
RUN  ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime \
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
     wget \
     zstd \
  && apt-get clean \
  && rm -r /var/lib/apt/lists

# Install SGX
ARG SGX_URL=https://download.01.org/intel-sgx/sgx-linux/2.17/distro/ubuntu20.04-server/sgx_linux_x64_sdk_2.17.100.3.bin
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
  && mkdir -p ${CARGO_HOME}/bin

# Install rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
  sh -s -- -y --default-toolchain nightly-2022-04-29


# Set up the builder-install image with more test helpers for CI.
FROM rust-sgx-base AS builder-install

SHELL ["/bin/bash", "-c"]

# Add sources for nodejs and install it and other helpers from apt.
RUN curl -LsSf https://deb.nodesource.com/setup_18.x | bash -s \
  && apt-get update \
  && apt-get install -y \
    nginx \
    nodejs \
    postgresql \
    postgresql-client \
    python3 \
    python3-pip \
  && apt-get clean \
  && rm -r /var/lib/apt/lists

# Setup postgresql for local testing
RUN sed -Ei -e '/127.0.0.1|::1/ s/md5/trust/g' /etc/postgresql/*/main/pg_hba.conf && \
  service postgresql start && \
  su postgres -c "createuser --superuser root"

# Install test helpers from released binaries.
RUN curl -LsSf https://get.nexte.st/latest/linux \
    | tar zxf - -C ${CARGO_HOME:-~/.cargo}/bin \
  && curl -LsSf https://github.com/eqrion/cbindgen/releases/download/v0.24.2/cbindgen \
    -o ${CARGO_HOME:-~/.cargo}/bin/cbindgen \
  && curl -LsSf https://github.com/mozilla/sccache/releases/download/v0.3.0/sccache-v0.3.0-x86_64-unknown-linux-musl.tar.gz \
    | tar xzf - -C ${CARGO_HOME:-~/.cargo}/bin --strip-components=1 sccache-v0.3.0-x86_64-unknown-linux-musl/sccache \
  && chmod 0755 ${CARGO_HOME:-~/.cargo}/bin/{cbindgen,sccache}
