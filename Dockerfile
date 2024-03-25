# Copyright (c) 2022 MobileCoin Inc.
FROM ubuntu:focal-20230126 as rust-sgx-base

SHELL ["/bin/bash", "-c"]

# Utilities:
# build-essential, cmake, curl, git, jq
#
# Build Requirements:
# libclang-dev, libprotobuf-dev, libpq-dev, libssl1.1,
# libssl-dev, llvm, llvm-dev, pkg-config
#
# Needed for GHA cache actions:
# zstd
#
# Needed for building ledger-mob and full service:
# libdbus-1-dev
#
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
     libdbus-1-dev \
     libhidapi-dev \
     libprotobuf-dev \
     libpq-dev \
     libssl1.1 \
     libssl-dev \
     libudev-dev \
     libusb-1.0-0-dev \
     llvm \
     llvm-dev \
     pkg-config \
     unzip \
     wget \
     zstd \
  && apt-get clean \
  && rm -r /var/lib/apt/lists

# Install a newer version of the protobuf compiler, that's not available in apt
RUN wget https://github.com/protocolbuffers/protobuf/releases/download/v25.2/protoc-25.2-linux-x86_64.zip \
  && unzip protoc-25.2-linux-x86_64.zip -d protoc \
  && cp protoc/bin/protoc /usr/bin/protoc \
  && cp -r protoc/include/google /usr/include/google \
  && rm -rf protoc 

# Install SGX
ARG SGX_URL=https://download.01.org/intel-sgx/sgx-linux/2.23/distro/ubuntu20.04-server/sgx_linux_x64_sdk_2.23.100.2.bin
RUN  curl -o sgx.bin "${SGX_URL}" \
  && chmod +x ./sgx.bin \
  && ./sgx.bin --prefix=/opt/intel \
  && rm ./sgx.bin

# Install DCAP libraries
ARG DCAP_VERSION=1.20.100.2-focal1
RUN mkdir -p /etc/apt/keyrings \
  && wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | gpg --dearmor -o /etc/apt/keyrings/intel-sgx.gpg \
  && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/intel-sgx.gpg] https://download.01.org/intel-sgx/sgx_repo/ubuntu focal main" | tee /etc/apt/sources.list.d/intel-sgx.list \
  && apt-get update \
  && apt-get install -y \
     libsgx-dcap-ql=${DCAP_VERSION} \
     libsgx-dcap-ql-dev=${DCAP_VERSION} \
     libsgx-dcap-quote-verify=${DCAP_VERSION} \
     libsgx-dcap-quote-verify-dev=${DCAP_VERSION} \
  && apt-get clean \
  && rm -r /var/lib/apt/lists

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
  sh -s -- -y --default-toolchain nightly-2023-01-22

# Set up the builder-install image with more test helpers for CI.
FROM rust-sgx-base AS builder-install

SHELL ["/bin/bash", "-c"]

# Install go 1.18 release
RUN GO_PKG=go1.18.5.linux-amd64.tar.gz \
  && wget https://golang.org/dl/$GO_PKG -O go.tgz \
  && tar -C /usr/local -xzf go.tgz \
  && rm -rf go.tgz

ENV GOPATH=/opt/go/
ENV PATH="/usr/local/go/bin:$GOPATH/bin:$PATH"
RUN mkdir -p "${GOPATH}"

RUN apt-get update \
  && apt-get install -y \
    nginx \
    postgresql \
    postgresql-client \
    python3 \
    python3-pip \
    psmisc \
    sudo \
  && apt-get clean \
  && rm -r /var/lib/apt/lists

# Setup postgresql for local testing
RUN sed -Ei -e '/127.0.0.1|::1/ s/md5/trust/g' /etc/postgresql/*/main/pg_hba.conf && \
  service postgresql start && \
  su postgres -c "createuser --superuser root"

# Install test helpers from released binaries.
RUN curl -LsSf https://get.nexte.st/latest/linux \
    | tar zxf - -C ${CARGO_HOME}/bin \
  && curl -LsSf https://github.com/eqrion/cbindgen/releases/download/v0.24.2/cbindgen \
    -o ${CARGO_HOME}/bin/cbindgen \
  && curl -LsSf https://github.com/mozilla/sccache/releases/download/v0.3.0/sccache-v0.3.0-x86_64-unknown-linux-musl.tar.gz \
    | tar xzf - -C ${CARGO_HOME}/bin --strip-components=1 sccache-v0.3.0-x86_64-unknown-linux-musl/sccache \
  && chmod 0755 ${CARGO_HOME}/bin/{cbindgen,sccache}

COPY entrypoint-builder-install.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
