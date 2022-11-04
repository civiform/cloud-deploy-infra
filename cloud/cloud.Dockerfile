# syntax=docker/dockerfile:1

# The eclipse-temurin image and the standard openJDK11 fails to run on M1 Macs because it is incompatible with ARM architecture. This
# workaround uses an aarch64 (arm64) image instead when an optional platform argument is set to arm64.
# Docker's BuildKit skips unused stages so the image for the platform that isn't used will not be built.

FROM eclipse-temurin:11.0.16_8-jre as amd64
FROM bellsoft/liberica-openjre-debian:11.0.16-8 as arm64

FROM ${TARGETARCH}

COPY --from=hashicorp/terraform:1.3.3 /bin/terraform /usr/local/bin/
COPY --from=amazon/aws-cli:2.8.9 /usr/local /usr/local
COPY --from=amazon/aws-cli:2.8.9 /aws /aws
# TODO(#3222): Add Azure CLI and make sure It works with arm64.

RUN /bin/sh -c set -o pipefail && apt-get update && \
	apt-get upgrade --yes && apt-get install --yes bash python3 git

COPY ./cloud/ cloud/
