#!/bin/bash
set -e

# Инициализация SSH
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Генерация SSH ключа только на мастере
if [ "$ROLE" = "master" ] && [ ! -f /root/.ssh/id_rsa ]; then
    echo "Generating master SSH key pair..."
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa -q
    cat /root/.ssh/id_rsa.pub > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

# Для воркеров: ждем ключ от мастера
if [ "$ROLE" = "worker" ]; then
    while [ ! -f /root/.ssh/authorized_keys ]; do
        echo "Waiting for master SSH key..."
        sleep 2
    done
fi

# Настройка SSH
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

echo -e "Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile /dev/null" > /root/.ssh/config
chmod 600 /root/.ssh/config

# Установка пароля
echo "root:${SSH_PASSWORD:-root}" | chpasswd

# Запуск SSH
/usr/sbin/sshd

# Настройка PVM
export PVM_ROOT=/usr/lib/pvm3
export PVM_ARCH=LINUX64
export PVM_RSH=/usr/bin/ssh
export PVM_EXPORT=DISPLAY

# Очистка PVM
pkill -9 pvmd || true
rm -rf /tmp/pvm* /root/.pvm/* /usr/lib/pvm3/lib/LINUX64/pvmd.lock

# Запуск PVM демона с расширенным логированием
echo "Starting PVM daemon..."
pvmd -d -n $(hostname) > /tmp/pvmd.log 2>&1 &

# Ожидание запуска PVM
for i in {1..30}; do
    if pvm ps >/dev/null 2>&1; then
        echo "PVM daemon started"
        break
    fi
    echo "PVM startup attempt $i/30..."
    sleep 2
done

# Логика worker
if [ "$ROLE" = "worker" ]; then
    echo "Worker $HOSTNAME initializing..."
    echo "$HOSTNAME" > "/root/.ssh/worker_hostname"
    
    # Проверка связи с мастером
    until ping -c 2 pvm-master; do
        echo "Waiting for master..."
        sleep 2
    done
    
    # Бесконечное ожидание
    tail -f /dev/null
    exit 0
fi

# Логика master
if [ "$ROLE" = "master" ]; then
    echo "Master node initializing..."
    
    # Ожидание 2 worker'ов
    total_timeout=900
    start_time=$(date +%s)
    while [ $(ls /root/.ssh/worker_hostname* 2>/dev/null | wc -l) -lt 2 ]; do
        current_time=$(date +%s)
        if [ $((current_time - start_time)) -ge $total_timeout ]; then
            echo "Timeout waiting for workers"
            docker network inspect pp-5_pvmnet
            exit 1
        fi
        echo "Waiting for workers... ($(ls /root/.ssh/worker_hostname* 2>/dev/null | wc -l)/2)"
        sleep 10
    done
    
    # Сбор хостов через Docker DNS
    WORKERS=$(docker network inspect pp-5_pvmnet -f '{{range .Containers}}{{.Name}} {{end}}')
    HOSTS="pvm-master $WORKERS"
    
    # Форсированное обновление known_hosts
    > /root/.ssh/known_hosts
    for host in $HOSTS; do
        ssh-keyscan -H $host >> /root/.ssh/known_hosts
        ssh-keyscan -H $host.pp-5_pvmnet >> /root/.ssh/known_hosts
        ssh-keyscan -H $(dig +short $host) >> /root/.ssh/known_hosts
    done
    
    # Интенсивная проверка SSH
    for host in $HOSTS; do
        echo "Testing SSH to $host"
        for i in {1..15}; do
            if ssh -o BatchMode=yes -o ConnectTimeout=5 root@$host "echo Connection-success"; then
                echo "SSH to $host OK"
                break
            else
                echo "SSH attempt $i to $host failed"
                sleep 10
            fi
        done
    done
    
    # Перезапуск PVM
    pvm halt || true
    pkill -9 pvmd
    rm -rf /tmp/pvm*
    sleep 10
    
    # Запуск PVM с расширенным логированием
    pvmd -d -n pvm-master > /tmp/pvmd.log 2>&1 &
    
    # Добавление хостов через прямое соединение
    for host in $HOSTS; do
        echo "Adding host: $host"
        for i in {1..15}; do
            if timeout 45 pvm addhosts $host; then
                echo "Host $host added"
                break
            else
                echo "Error adding $host, retry $i"
                sleep 15
                pvm delhosts $host 2>/dev/null || true
            fi
        done
    done
    
    # Принудительная синхронизация
    pvmctl -n pvm-master reconfig
    sleep 5
    
    # Финальная проверка
    echo "PVM Configuration:"
    pvm conf -v
    echo "Active Hosts:"
    pvm hosts -v
    
    # Логирование статуса
    pvmdstatus -n pvm-master
    netstat -tulpn | grep pvm
    
    # Запуск приложения
    echo "Starting application..."
    exec /app/build/main
fi