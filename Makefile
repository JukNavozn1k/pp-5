CXX = g++
CXXFLAGS = -Wall -Wextra -std=c++17
SRC_DIR = src
BIN_DIR = bin
TARGET = $(BIN_DIR)/hello
SRCS = $(wildcard $(SRC_DIR)/*.cpp)
OBJS = $(SRCS:.cpp=.o)

all: $(BIN_DIR) $(TARGET)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TARGET): $(SRCS)
	$(CXX) $(CXXFLAGS) $^ -o $@

clean:
	rm -rf $(BIN_DIR) *.o $(SRC_DIR)/*.o

.PHONY: all clean
