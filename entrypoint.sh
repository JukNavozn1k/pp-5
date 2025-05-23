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
# Отключаем аутентификацию по паролю, только по ключу
if ! grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
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

# Перезапускаем sshd для применения настроек
pkill sshd || true
/usr/sbin/sshd

# Ждем запуска демона PVM
pvm &
sleep 2

# Сохраняем hostname воркера (или master) в volume
hostname > /root/.ssh/worker_hostname_$(hostname)

if [ "$ROLE" = "master" ]; then
    # Ждем появления hostnames от всех воркеров (ожидаем 1 по умолчанию, можно увеличить)
    WORKER_COUNT=${WORKER_COUNT:-1}
    echo "Ожидание hostnames от $WORKER_COUNT воркеров..."
    while [ $(ls /root/.ssh/worker_hostname_* 2>/dev/null | wc -l) -lt $WORKER_COUNT ]; do
        sleep 1
    done
    # Собираем hostnames в файл
    cat /root/.ssh/worker_hostname_* > /root/.ssh/pvm_hosts
    echo "Список воркеров:"
    cat /root/.ssh/pvm_hosts
    # Добавляем воркеров в known_hosts
    while read host; do
        ssh-keyscan -H $host >> /root/.ssh/known_hosts 2>/dev/null
    done < /root/.ssh/pvm_hosts
    # Проверяем SSH доступность
    while read host; do
        until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 root@$host hostname; do
            echo "Ожидание SSH для $host..."; sleep 1;
        done
    done < /root/.ssh/pvm_hosts
    /app/build/main
    pvm halt
else
    /app/build/main worker &
    exec /usr/sbin/sshd -D
fi
