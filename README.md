# docker-rust-sgx-base
Base image for Rust with SGX libraries.

For use in downstream builds to provide a consistent and verifiable Rust build environment.

We recommend referencing the image by the hash instead of a tag to verify a consistent build environment.

# Builds

### mobilecoin/rust-base (arm64/amd64)

`rust-base` can be used by CI/CD for building and testing mobilecoin rust projects.

To build locally.
```
docker build -f ./Dockerfile.rust-base -t mobilecoin/rust-base:latest .
```

### mobilecoin/rust-sgx (amd64)

`rust-sgx-base` can be used by CI/CD for building and testing mobilecoin rust projects that require SGX libraries. This image is only available as a amd64(X64) image.

1. Build `rust-base` image with the `latest` tag.
2. Build `rust-sgx` image using `rust-base` as the `FROM` image.
    ```
    docker build -f ./Dockerfile.rust-sgx -t mobilecoin/rust-sgx:latest .
    ```

### mobilecoin/fat-builder (arm64/amd64)

`fat-builder` includes some handy tools used for local development. Build this image off the `fat-builder` docker file using `rust-base` as the `FROM` image. This image does not include SGX libraries or tools.

1. Build `rust-base` image with the `latest` tag.
2. Build `fat-builder` image
    ```
    docker build -f ./Dockerfile.fat-builder -t mobilecoin/fat-builder:latest .
    ```

### mobilecoin/fat-sgx-builder (amd64)

`fat-sgx-builder` includes some handy tools used for local development along with the SGX libraries. This image is only available for amd64(X64). Build this image off the `fat-builder` docker file using `rust-sgx` as the `FROM` image. This image includes SGX libraries or tools.

1. Build `rust-base` image with the `latest` tag.
2. Build `rust-sgx` image with the `latest` tag.
2. Build `fat-sgx-builder` image
    ```
    docker build --build-arg BASE_IMAGE=rust-sgx -f ./Dockerfile.fat-builder -t mobilecoin/fat-sgx-builder:latest .
    ```
