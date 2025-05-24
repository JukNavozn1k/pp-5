# Makefile for building main.cpp with PVM support

# Компилятор и флаги
CXX := g++
CXXFLAGS := -O2 -Wall -std=c++17
PVMFLAGS := -I$(PVM_ROOT)/include -L$(PVM_ROOT)/lib/$(PVM_ARCH) -lpvm3

# Пути
SRC := ./src/main.cpp
OUTDIR := ./build
TARGET := $(OUTDIR)/main

# Правила
all: $(TARGET)

$(TARGET): $(SRC) | $(OUTDIR)
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET) $(PVMFLAGS)

$(OUTDIR):
	mkdir -p $(OUTDIR)

clean:
	rm -rf $(OUTDIR)

.PHONY: all clean
