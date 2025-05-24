FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    pvm \
    pvm-dev \
    make \
    g++ \
    openssh-server \
    iputils-ping \
    dnsutils \
    net-tools \
    strace \
    dos2unix \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd && \
    ssh-keygen -A

WORKDIR /app
COPY ./src ./src
COPY Makefile ./

RUN make

ENV PVM_ROOT=/usr/lib/pvm3
ENV PVM_ARCH=LINUX64
ENV PVM_DPATH=/tmp
ENV PVM_TMP=/tmp

EXPOSE 4096-4196 22

COPY entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]