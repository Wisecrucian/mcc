.PHONY: setup build run clean install archive dist help

# Paths
BUILD_DIR = ~/Library/Developer/Xcode/DerivedData/MCCPortForwarder-*/Build/Products
DIST_DIR = dist
APP_NAME = MCCPortForwarder

# Read version from build.number
VERSION := $(shell cat build.number 2>/dev/null || echo "unknown")

setup:
	@./setup.sh

build:
	@echo "🔨 Building Release version..."
	@xcodebuild -project MCCPortForwarder.xcodeproj \
		-scheme MCCPortForwarder \
		-configuration Release \
		-derivedDataPath ./build \
		build
	@echo "✅ Build complete: ./build/Build/Products/Release/MCCPortForwarder.app"

run:
	@echo "🚀 Building and running Debug version..."
	@xcodebuild -project MCCPortForwarder.xcodeproj \
		-scheme MCCPortForwarder \
		-configuration Debug \
		build
	@open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/MCCPortForwarder.app

clean:
	@echo "🧹 Cleaning..."
	@xcodebuild -project MCCPortForwarder.xcodeproj \
		-scheme MCCPortForwarder \
		clean
	@rm -rf ~/Library/Developer/Xcode/DerivedData/MCCPortForwarder-*
	@rm -rf build
	@rm -rf $(DIST_DIR)
	@echo "✅ Clean complete"

install: build
	@echo "📦 Installing to /Applications..."
	@cp -R ./build/Build/Products/Release/$(APP_NAME).app /Applications/
	@echo "✅ Installed to /Applications/$(APP_NAME).app"

# Create distributable archive
archive: build
	@echo "📦 Creating distributable archive..."
	@echo "📌 Version: $(VERSION)"
	@mkdir -p $(DIST_DIR)
	@cp -R ./build/Build/Products/Release/$(APP_NAME).app $(DIST_DIR)/
	@cd $(DIST_DIR) && zip -r ../$(APP_NAME)-v$(VERSION).zip $(APP_NAME).app
	@echo "✅ Archive created: $(APP_NAME)-v$(VERSION).zip"
	@ls -lh $(APP_NAME)-v$(VERSION).zip

# Full distribution package
dist: clean build archive
	@echo ""
	@echo "🎉 Distribution package ready!"
	@echo ""
	@echo "📦 File: $(APP_NAME)-v$(VERSION).zip"
	@echo "📍 Location: $(shell pwd)/$(APP_NAME)-v$(VERSION).zip"
	@echo "📊 Size: $(shell ls -lh $(APP_NAME)-v$(VERSION).zip | awk '{print $$5}')"
	@echo "🏷️  Version: $(VERSION)"
	@echo ""
	@echo "To distribute:"
	@echo "  1. Share $(APP_NAME)-v$(VERSION).zip"
	@echo "  2. User extracts and copies .app to /Applications/"
	@echo "  3. User runs from Applications or Spotlight"
	@echo ""

# Show app info
info:
	@echo "📱 Application Information:"
	@echo ""
	@if [ -d "./build/Build/Products/Release/$(APP_NAME).app" ]; then \
		echo "✅ Release build exists"; \
		plutil -p "./build/Build/Products/Release/$(APP_NAME).app/Contents/Info.plist" | grep -E "CFBundle"; \
		echo ""; \
		echo "📊 Size: $$(du -sh "./build/Build/Products/Release/$(APP_NAME).app" | cut -f1)"; \
		echo "📍 Path: ./build/Build/Products/Release/$(APP_NAME).app"; \
	else \
		echo "❌ Release build not found. Run 'make build' first."; \
	fi

help:
	@echo "MCC Port Forwarder - Available commands:"
	@echo ""
	@echo "Development:"
	@echo "  make setup    - Generate Xcode project (first time)"
	@echo "  make run      - Build and run debug version"
	@echo "  make clean    - Clean build artifacts"
	@echo ""
	@echo "Release & Distribution:"
	@echo "  make build    - Build release version"
	@echo "  make archive  - Create .zip for distribution"
	@echo "  make dist     - Full clean build + archive"
	@echo "  make install  - Install to /Applications"
	@echo ""
	@echo "Utility:"
	@echo "  make info     - Show app information"
	@echo "  make help     - Show this help"
	@echo ""

