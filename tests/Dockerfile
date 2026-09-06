FROM alpine:3.22

RUN apk add --no-cache \
    bash \
    coreutils \
    libxml2-utils \
    procps \
    wget \
    xz

COPY . /repo

RUN sed -i 's/\r$//' /repo/tests/docker-smoke-test.sh

ENTRYPOINT ["/bin/bash", "/repo/tests/docker-smoke-test.sh"]
