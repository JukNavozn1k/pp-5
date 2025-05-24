#!/bin/bash
set -e

# --- Часть под root: настраиваем SSH и ключи для pvmuser, затем переключаемся на него ---
if [ "$(id -u)" = "0" ]; then

  # 1) Создаём директории для привилегированного разделения sshd
  mkdir -p /run/sshd /var/run/sshd
  chmod 755 /run/sshd /var/run/sshd

  # 2) Настройка .ssh в home pvmuser (volume sshkeys примонтирован сюда)
  mkdir -p /home/pvmuser/.ssh
  chmod 700 /home/pvmuser/.ssh

  if [ "$ROLE" = "master" ] && [ ! -f /home/pvmuser/.ssh/id_rsa ]; then
    echo "Generating master SSH key pair..."
    ssh-keygen -t rsa -N "" -f /home/pvmuser/.ssh/id_rsa -q
    cp /home/pvmuser/.ssh/id_rsa.pub /home/pvmuser/.ssh/authorized_keys
  fi

  if [ "$ROLE" = "worker" ]; then
    echo "Worker waiting for master key..."
    while [ ! -f /home/pvmuser/.ssh/authorized_keys ]; do
      sleep 2
    done
  fi

  chmod 600 /home/pvmuser/.ssh/{id_rsa,authorized_keys}
  cat <<EOF > /home/pvmuser/.ssh/config
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
  chmod 600 /home/pvmuser/.ssh/config
  chown -R pvmuser:pvmuser /home/pvmuser/.ssh

  # 3) Разрешаем root-логин и отключаем пароль (SSH-демон)
  sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

  # 4) Стартуем SSH-демон
  /usr/sbin/sshd

  # 5) Перезапускаем тот же скрипт уже от pvmuser
  exec su - pvmuser -c "/entrypoint.sh"
fi

# === Дальше мы уже под pvmuser ===

export PVM_ROOT=/usr/lib/pvm3
export PVM_ARCH=LINUX64
export PVM_RSH=/usr/bin/ssh
export PVM_ALLOW_ROOT=1

# Чистим старые демоны и lock-файлы
pkill -9 pvmd >/dev/null 2>&1 || true
rm -rf /tmp/pvm* "$HOME/.pvm"/* $PVM_ROOT/lib/$PVM_ARCH/pvmd.lock

# Запускаем PVM-демона
echo "Starting PVM daemon on $(hostname)..."
pvmd -d -n $(hostname) > /tmp/pvmd.log 2>&1 &

# Ждём, пока pvmd станет доступен
for i in {1..30}; do
  if pvm ps >/dev/null 2>&1; then
    echo "PVM daemon started"
    break
  fi
  sleep 1
done

if [ "$ROLE" = "worker" ]; then
  echo "Worker $(hostname) ready"
  echo "$(hostname)" > "$HOME/.ssh/worker_hostname"
  tail -f /dev/null
  exit 0
fi

# === Режим master ===

echo "Master node initializing..."
timeout=900
start=$(date +%s)
while [ "$(ls $HOME/.ssh/worker_hostname* 2>/dev/null | wc -l)" -lt 2 ]; do
  if [ $(( $(date +%s) - start )) -ge $timeout ]; then
    echo "Timeout waiting for workers"
    exit 1
  fi
  sleep 5
done

HOSTS="pvm-master worker-1 worker-2"
> $HOME/.ssh/known_hosts
for h in $HOSTS; do
  ssh-keyscan -H $h >> $HOME/.ssh/known_hosts
done

for h in $HOSTS; do
  until ssh -o BatchMode=yes -o ConnectTimeout=5 pvmuser@$h "echo ok"; do
    sleep 2
  done
done

pvm halt >/dev/null 2>&1 || true
pkill -9 pvmd
rm -rf /tmp/pvm* "$HOME/.pvm"/*
sleep 2
pvmd -d -n pvm-master > /tmp/pvmd.log 2>&1 &
sleep 5

for h in $HOSTS; do
  for i in {1..5}; do
    if pvm add $h; then break; else
      pvm delhost $h >/dev/null 2>&1 || true
      sleep 2
    fi
  done
done

echo "Final PVM config:"
pvm conf -v

# Запускаем ваше приложение
exec /app/build/main
