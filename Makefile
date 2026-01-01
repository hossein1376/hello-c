# Makefile for hello-c

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
# Combine and uniquify
SRCS := $(sort $(SRCS_SRC) $(SRCS_TOP))

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

all: $(TARGET)

# Ensure build directory exists
$(BUILD_DIR):
	$(Q)mkdir -p $(BUILD_DIR)

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

# Include generated dependency files (if they exist). The leading '-' hides missing-file errors.
-include $(DEPS)
