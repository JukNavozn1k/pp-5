#!/bin/bash
set -e

# Генерация SSH-ключей и настройка authorized_keys (один раз на контейнер)
if [ ! -f /root/.ssh/id_rsa ]; then
    mkdir -p /root/.ssh
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi
# Разрешаем root вход по ssh
if ! grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
fi

# Запуск sshd
/usr/sbin/sshd

# Запуск демона PVM на всех контейнерах
pvm &

# Ждем запуска демона
sleep 2

# Если это мастер, добавляем воркеров в кластер
if [ "$ROLE" = "master" ]; then
    # Добавляем всех воркеров (worker-1, worker-2, ..., worker-N)
    for i in $(seq 1 7); do
        pvm add worker-$i || true
    done
    /app/build/main
    # Останавливаем кластер после завершения
    pvm halt
else
    # Воркеры ждут команд
    /app/build/main worker
fi
