FROM ubuntu:focal-20211006

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
     libssl1.1 \
     libssl-dev \
     llvm \
     llvm-dev \
     pkg-config \
     protobuf-compiler \
  && apt-get clean \
  && rm -r /var/lib/apt/lists

SHELL ["/bin/bash", "-c"]
# Install SGX

ARG SGX_URL=https://download.01.org/intel-sgx/sgx-linux/2.13.3/distro/ubuntu20.04-server/sgx_linux_x64_sdk_2.13.103.1.bin
RUN curl -o sgx.bin "${SGX_URL}" \
  && chmod +x ./sgx.bin \
  && ./sgx.bin --prefix=/opt/intel \
  && rm ./sgx.bin \
  && echo '. /opt/intel/sgxsdk/environment' >> /root/.bashrc

# Install rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly-2020-07-01

ENV SGX_SDK=/opt/intel/sgxsdk
ENV PATH=/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/intel/sgxsdk/bin:/opt/intel/sgxsdk/bin/x64
ENV PKG_CONFIG_PATH=/opt/intel/sgxsdk/pkgconfig
ENV LD_LIBRARY_PATH=/opt/intel/sgxsdk/sdk_libs

# Add additonal toolchains
RUN rustup toolchain install nightly-2021-03-25
RUN rustup toolchain install nightly-2021-07-21
