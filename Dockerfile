FROM ubuntu:bionic-20210416

RUN  apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y \
     git \
     curl \
     jq \
     build-essential \
     cmake \
     protobuf-compiler \
     libprotobuf-dev \
     llvm \
     llvm-dev \
     clang \
     libclang-dev \
     libssl1.1 \
  && apt-get clean \
  && rm -r /var/lib/apt/lists

SHELL ["/bin/bash", "-c"]

# Install SGX sgx_linux_x64_sdk_2.9.101.2.bin
RUN curl -O https://download.01.org/intel-sgx/sgx-linux/2.9.1/distro/ubuntu18.04-server/sgx_linux_x64_sdk_2.9.101.2.bin \
  && chmod +x ./sgx_linux_x64_sdk_2.9.101.2.bin \
  && ./sgx_linux_x64_sdk_2.9.101.2.bin --prefix=/opt/intel \
  && rm ./sgx_linux_x64_sdk_2.9.101.2.bin \
  && echo '. /opt/intel/sgxsdk/environment' >> /root/.bashrc

# Install rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly-2020-07-01

ENV SGX_SDK=/opt/intel/sgxsdk
ENV PATH=/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/intel/sgxsdk/bin:/opt/intel/sgxsdk/bin/x64
ENV PKG_CONFIG_PATH=/opt/intel/sgxsdk/pkgconfig
ENV LD_LIBRARY_PATH=/opt/intel/sgxsdk/sdk_libs

# Add additonal toolchains
RUN rustup toolchain install nightly-2021-03-25