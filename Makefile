.PHONY: build install clean test help

VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_DIR := ./bin
BINARY_NAME := limitless-codex
INSTALL_DIR := ~/.local/bin

help:
	@echo "limitless-codex build targets:"
	@echo "  make build      - Build binary"
	@echo "  make install    - Build and install to ~/.local/bin"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make test       - Run tests"

build:
	@mkdir -p $(BUILD_DIR)
	@go build -o $(BUILD_DIR)/$(BINARY_NAME) \
		-ldflags="-X main.Version=$(VERSION)" \
		./cmd/limitless-codex
	@echo "✓ Built $(BUILD_DIR)/$(BINARY_NAME) ($(VERSION))"

install: build
	@mkdir -p $(INSTALL_DIR)
	@rm -f $(INSTALL_DIR)/$(BINARY_NAME)
	@cp $(BUILD_DIR)/$(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME)
	@chmod +x $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "✓ Installed to $(INSTALL_DIR)/$(BINARY_NAME)"

clean:
	@rm -rf $(BUILD_DIR)
	@echo "✓ Cleaned"

test:
	@go test -v ./...
