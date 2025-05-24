FROM ubuntu:18.04

# 1) Устанавливаем все необходимые пакеты
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
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

# 2) Добавляем непривилегированного пользователя для PVM
RUN useradd -m -s /bin/bash pvmuser

# 3) Создаём директорию для SSHD и даём права
RUN mkdir -p /run/sshd && chmod 0755 /run/sshd

# 4) Создаём папку для ssh ключей пользователя pvmuser
RUN mkdir -p /home/pvmuser/.ssh && chown -R pvmuser:pvmuser /home/pvmuser/.ssh

# 5) Рабочая директория
WORKDIR /app
COPY ./src ./src
COPY Makefile ./
RUN make

# 6) Копируем entrypoint и даём ему права
COPY entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

# 7) Порты PVM и SSH
EXPOSE 4096-4196/tcp 4096-4196/udp 22

# 8) Запускать контейнер от пользователя pvmuser
USER pvmuser

ENTRYPOINT ["/entrypoint.sh"]
