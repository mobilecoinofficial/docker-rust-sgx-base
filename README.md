# docker-rust-sgx-base
Base image for Rust with SGX libraries.

For use in downstream builds to provide a consistent and verifiable Rust build environment.

We recommend referencing the image by the hash instead of a tag to verify a consistent build environment.

# Build

The following command will build and tag `rust-sgx-base:latest`. (But not push it to dockerhub, the tag will be local to your machine.)

```
docker build -t mobilecoin/rust-sgx-base --target rust-sgx-base .
```

This variation will build and tag `builder-install:latest`.

```
docker build -t mobilecoin/builder-install .
```

A third variation is available, `rust-base`, which does not include the SGX SDKs. This facilitates building blockchain clients on non-intel architectures, e.g. linux/arm64.

```
docker build -t mobilecoin/rust-base --target rust-base .
```

To help iterate on a `builder-install` image, you can test it by opening a prompt
using the [`mob prompt` tool in `mobilecoin`](https://github.com/mobilecoinfoundation/mobilecoin/blob/master/mob).
Then you can try to build rust code, or go code, or really whatever your heart desires.

```
./mob prompt --tag latest --no-pull
```
