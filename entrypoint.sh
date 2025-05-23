#!/bin/bash
set -e

# Генерация ssh-ключа только если его нет (теперь ключ общий для всех через volume)
if [ ! -f /root/.ssh/id_rsa ]; then
    mkdir -p /root/.ssh
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
fi
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Разрешаем root вход по ssh
if ! grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
fi

# Прописываем PVM_ROOT и PVM_ARCH в .bashrc для ssh-сессий
if ! grep -q "PVM_ROOT" /root/.bashrc; then
    echo "export PVM_ROOT=/usr/lib/pvm3" >> /root/.bashrc
    echo "export PVM_ARCH=LINUX64" >> /root/.bashrc
fi

# Устанавливаем пароль root из переменной окружения (по умолчанию root)
if [ -n "$SSH_PASSWORD" ]; then
    echo "root:$SSH_PASSWORD" | chpasswd
fi

# Запуск sshd
/usr/sbin/sshd

# Ждем запуска демона PVM
pvm &
sleep 2

if [ "$ROLE" = "master" ]; then
    /app/build/main
    pvm halt
else
    /app/build/main worker
fi
