#!/bin/bash

set -e -o pipefail

case ${TARGETARCH:?} in
    amd64)
        PROTOC=protoc-25.2-linux-x86_64.zip
        ;;
    arm64)
        PROTOC=protoc-25.2-linux-aarch_64.zip
        ;;
    *)
        echo "Unsupported architecture: ${TARGETARCH}"
        exit 1
        ;;
    esac

curl -sSL -o protoc.zip "https://github.com/protocolbuffers/protobuf/releases/download/v25.2/${PROTOC}"
unzip protoc.zip -d protoc
cp protoc/bin/protoc /usr/bin/protoc
cp -r protoc/include/google /usr/include/google
rm -rf protoc protoc.zip
