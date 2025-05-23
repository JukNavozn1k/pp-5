#!/bin/bash
set -e

# Запуск демона PVM
pvm &

# Ждем запуска демона
sleep 2

# Если это мастер, запускаем main, иначе ждем команд от мастера
if [ "$ROLE" = "master" ]; then
    /app/build/main
    # Останавливаем кластер после завершения
    pvm halt
else
    # Воркеры ждут команд
    /app/build/main worker
fi
