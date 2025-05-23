FROM ubuntu:22.04

# Установка зависимостей
RUN apt-get update && \
    apt-get install -y build-essential pvm pvm-dev make g++ openssh-server && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Настройка SSH
RUN mkdir /var/run/sshd && \
    echo 'root:root' | chpasswd && \
    ssh-keygen -A

# Копируем исходники
WORKDIR /app
COPY ./src ./src
COPY Makefile ./

# Сборка приложения
RUN make
# Копируем собранный бинарник в src/main для совместимости со скриптом (или меняем путь в entrypoint.sh)
RUN cp build/main src/main

# Установка переменных окружения для PVM
ENV PVM_ROOT=/usr/lib/pvm3
ENV PVM_ARCH=LINUX64
ENV PVM_DPATH=/tmp
ENV PVM_TMP=/tmp

# Открываем порты для PVM и SSH
EXPOSE 4096-4196 22

# Копируем скрипт запуска
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
