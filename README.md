# PVM Parallel Implementation of Computationally Intensive Algorithm

Реализация вычислительно сложного алгоритма с использованием программного пакета PVM (Parallel Virtual Machine) на языке C++. Реализована параллельная версия алгоритма с передачей сообщений между процессами в гетерогенной вычислительной среде.

## 📦 Зависимости

Для сборки и запуска необходимы следующие инструменты и библиотеки:

- Компилятор `g++` с поддержкой C++ (обычно `g++` из `build-essential`)
- Системные утилиты `make`, `gcc`
- Пакет PVM (Parallel Virtual Machine)
- SSH (если планируется запуск задач на нескольких хостах)
- Библиотеки и заголовочные файлы POSIX (часть стандартной системы Linux)

### Установка основных зависимостей (Ubuntu / WSL):

```bash
sudo apt update
sudo apt install build-essential g++ make openssh-client openssh-server
sudo apt install -y pvm
