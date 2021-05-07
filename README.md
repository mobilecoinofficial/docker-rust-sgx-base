# docker-rust-sgx-base
Base image for Rust with SGX libraries.

For use in downstream builds to provide a consistent and verifiable Rust build environment.

We recommend referencing the image by the hash instead of a tag to verify a consistent build environment.

# Build

```
docker build -t mobilecoin/rust-sgx-base .
```
