.PHONY: build install app install-app clean test help

VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_DIR := ./bin
BINARY_NAME := limitless-codex
INSTALL_DIR := ~/.local/bin
APP := $(BUILD_DIR)/limitless-codex.app
APP_VERSION := $(shell echo $(VERSION) | sed -E 's/^v//; s/-.*//')
SWIFTC ?= xcrun swiftc

help:
	@echo "limitless-codex build targets:"
	@echo "  make build      - Build binary"
	@echo "  make install    - Build and install to ~/.local/bin"
	@echo "  make app        - Build limitless-codex.app (macOS)"
	@echo "  make install-app - Install the app to ~/Applications, CLI to ~/.local/bin"
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

# The monitor ships inside the app so notifications carry the app's name and icon.
# Signed ad hoc: no Apple Developer account involved.
app:
	@rm -rf $(APP)
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	@go build -o $(APP)/Contents/MacOS/$(BINARY_NAME) -ldflags="-X main.Version=$(VERSION)" ./cmd/limitless-codex
	@$(SWIFTC) -O -o $(APP)/Contents/MacOS/LimitlessCodex app/Sources/*.swift
	@sed 's/VERSION/$(APP_VERSION)/g' app/Info.plist > $(APP)/Contents/Info.plist
	@cp -R app/Resources/ $(APP)/Contents/Resources/
	@codesign --force --sign - $(APP)
	@echo "✓ Built $(APP) ($(APP_VERSION))"

install-app: app
	@mkdir -p ~/Applications $(INSTALL_DIR)
	@rm -rf ~/Applications/limitless-codex.app
	@cp -R $(APP) ~/Applications/
	@ln -sf ~/Applications/limitless-codex.app/Contents/MacOS/$(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "✓ Installed ~/Applications/limitless-codex.app; run: limitless-codex setup"

clean:
	@rm -rf $(BUILD_DIR)
	@echo "✓ Cleaned"

test:
	@go test -v ./...
