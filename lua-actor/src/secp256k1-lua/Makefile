# Makefile for Lua module using pre-built static library (libsecp256k1.a)

# macOS-specific settings
LUAINCLUDE = $(shell brew --prefix lua)/include/lua5.4
LUALIB = $(shell brew --prefix lua)/lib

# Compiler settings
CC = gcc
CFLAGS = -Wall -fPIC -O2 -I$(LUAINCLUDE)

# Pre-built static library information
STATIC_LIB_NAME = libsecp256k1.a
STATIC_LIB_DIR = $(shell pwd)
STATIC_LIB = $(STATIC_LIB_DIR)/$(STATIC_LIB_NAME)

# Library files
LUA_MODULE_NAME = secp256k1.so
LUA_MODULE = $(LUA_MODULE_NAME)

# Header location (adjust if needed)
SECP256K1_INCLUDE = $(STATIC_LIB_DIR)

# Main targets
all: check_lib $(LUA_MODULE)

# Check if pre-built static library exists
check_lib:
	@echo "Looking for static library at: $(STATIC_LIB)"
	@if [ ! -f "$(STATIC_LIB)" ]; then \
		echo "Error: $(STATIC_LIB_NAME) not found"; \
		echo "Current directory: $(STATIC_LIB_DIR)"; \
		echo "Files in directory:"; \
		ls -la $(STATIC_LIB_DIR); \
		exit 1; \
	else \
		echo "Found $(STATIC_LIB_NAME)"; \
	fi

# Compile Lua wrapper
secp256k1_lua.o: secp256k1_lua.c
	$(CC) $(CFLAGS) -I$(SECP256K1_INCLUDE) -c secp256k1_lua.c -o secp256k1_lua.o

# Create Lua loadable module using the pre-built static library
$(LUA_MODULE): secp256k1_lua.o
	# For static libraries, we link the entire library into the module
	$(CC) -bundle -undefined dynamic_lookup -o $(LUA_MODULE) secp256k1_lua.o $(STATIC_LIB)
	@echo "Created $(LUA_MODULE) successfully"
	@otool -L $(LUA_MODULE)

# Clean up
clean:
	rm -f *.o $(LUA_MODULE)

.PHONY: all clean check_lib