# Makefile for hello-c
# - Builds program at build/prog (matches .zed/debug.json)
# - Sources expected in src/ and optionally top-level .c files next to the Makefile
# - Headers expected in include/
# - Supports VERBOSE=1 to show commands, INC_DIRS for extra include paths,
#   automatic dependency generation, and common targets.
#
# Usage:
#   make -j8                 # parallel build (matches debug.json)
#   make VERBOSE=1           # show full compile/link commands
#   make INC_DIRS="foo bar"  # add include dirs relative to project root
#   make run                 # run built program
#
# Variables you can override:
#   CC, CFLAGS, LDFLAGS, INC_DIRS, BUILD_DIR, SRC_DIR, INCDIR

# Toolchain (override on the command line if needed)
CC ?= gcc

# Directory where this Makefile lives (works even if make invoked from another CWD)
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Source and include layout (relative to MAKEFILE_DIR)
SRC_DIR ?= $(MAKEFILE_DIR)src
INCDIR ?= $(MAKEFILE_DIR)include

# Additional include directories (space-separated, relative to MAKEFILE_DIR or absolute)
INC_DIRS ?=

# Convert INC_DIRS into -I flags. If an entry is relative, prefix with MAKEFILE_DIR.
# Simple heuristic: if it begins with /, keep as-is; otherwise prefix.
ifeq ($(INC_DIRS),)
INC_FLAGS :=
else
INC_FLAGS :=
# transform each word in INC_DIRS into -I<path>
$(foreach d,$(INC_DIRS),$(eval _d := $(d))$(eval _pref := $(if $(filter /%,$(_d)),$(_d),$(MAKEFILE_DIR)$(_d)))$(eval INC_FLAGS += -I$(_pref)))
endif

# Always include the canonical include/ dir
CPPFLAGS ?= -I$(INCDIR) $(INC_FLAGS)

# Compilation flags
CFLAGS ?= -std=c11 -Wall -Wextra -O2 -g
# Emit dependency files (.d) and phony targets for missing headers
CFLAGS += -MMD -MP

LDFLAGS ?=

# Build layout
BUILD_DIR ?= build
TARGET := $(BUILD_DIR)/prog

# Discover sources: both files under src/ and top-level .c next to the Makefile
SRCS_SRC := $(wildcard $(SRC_DIR)/*.c)
SRCS_TOP := $(wildcard $(MAKEFILE_DIR)/*.c)
# Filter out common non-source files (Makefile itself won't match *.c, but keep defensively)
# Combine and uniquify
SRCS := $(sort $(SRCS_SRC) $(SRCS_TOP))
ifeq ($(strip $(SRCS)),)
$(error No C source files found in $(SRC_DIR) or next to the Makefile ($(MAKEFILE_DIR)). Put .c files under src/ or next to the Makefile.)
endif

# Use basenames for object mapping so both src/foo.c and top-level foo.c produce build/foo.o
SRCS_BASENAME := $(notdir $(SRCS))
OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS_BASENAME))
DEPS := $(OBJS:.o=.d)

.PHONY: all buildprog clean rebuild run format check help

# Verbose control: set VERBOSE=1 to see full compiler/linker commands
ifeq ($(VERBOSE),1)
Q :=
else
Q := @
endif

# Default target (used by `make` and by the debugger which runs `make -j8`)
all: $(TARGET)

# Ensure build directory exists
$(BUILD_DIR):
	$(Q)mkdir -p $(BUILD_DIR)

# Compile rules:
#  - compile src/<name>.c -> build/<name>.o
#  - compile top-level <name>.c -> build/<name>.o
# Having both pattern rules lets make select the correct prerequisite based on what's present.

# src/ sources
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(BUILD_DIR)
	$(Q)$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

# top-level sources (next to Makefile)
$(BUILD_DIR)/%.o: $(MAKEFILE_DIR)%.c | $(BUILD_DIR)
	$(Q)$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

# Link the program at build/prog
$(TARGET): $(OBJS)
	$(Q)$(CC) $(LDFLAGS) -o $@ $^

# Convenience alias (avoid colliding with the build directory name)
buildprog: all

# Rebuild from scratch
rebuild: clean all

# Run the program
run: $(TARGET)
	$(Q)./$(TARGET)

# Clean build artifacts
clean:
	$(Q)rm -rf $(BUILD_DIR)

# Format sources with clang-format if available (applies to src and include)
format:
	@if command -v clang-format >/dev/null 2>&1; then \
		clang-format -i $(SRCS) $(wildcard $(INCDIR)/*.[hH]); \
		echo "Formatted sources and headers"; \
	else \
		echo "clang-format not found; skipping"; \
	fi

# Compile-only check: treat warnings as errors
check:
	$(Q)$(CC) $(CPPFLAGS) $(CFLAGS) -Werror -o /dev/null -c $(SRCS)

help:
	@echo "Makefile targets:"
	@echo "  make (or make all)          -> build $(TARGET)"
	@echo "  make buildprog              -> explicit build alias"
	@echo "  make -j8                    -> parallel build (matches debug.json)"
	@echo "  make VERBOSE=1              -> show full compile/link commands"
	@echo "  make INC_DIRS=\"inc other\"  -> add include dirs (space-separated, relative to project root)"
	@echo "  make CC=clang               -> override compiler"
	@echo "  make run                    -> run the built program"
	@echo "  make clean                  -> remove build artifacts"
	@echo "  make format                 -> run clang-format on sources"
	@echo "  make check                  -> compile with -Werror"

# Include generated dependency files (if they exist). The leading '-' hides missing-file errors.
-include $(DEPS)
