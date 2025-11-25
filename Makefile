.PHONY: all build test clean samples lint format help \
        sample-macro run-sample-macro

# Default target
all: build

# Build the main package
build:
	swift build

# Build for release
release:
	swift build -c release

# Run tests
test:
	swift test

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Build all sample apps
samples: sample-macro

# Build MacroSampleApp
sample-macro:
	@echo "Building MacroSampleApp..."
	cd Examples/MacroSampleApp && swift build

# Run MacroSampleApp
run-sample-macro:
	@echo "Running MacroSampleApp..."
	cd Examples/MacroSampleApp && swift run

# Lint code
lint:
	swiftlint lint --strict

# Format code
format:
	swift-format format -i -r Sources Tests

# Generate Xcode project
xcode:
	swift package generate-xcodeproj

# Update dependencies
update:
	swift package update

# Show help
help:
	@echo "Available targets:"
	@echo "  all              - Build the main package (default)"
	@echo "  build            - Build the main package"
	@echo "  release          - Build for release"
	@echo "  test             - Run tests"
	@echo "  clean            - Clean build artifacts"
	@echo "  samples          - Build all sample apps"
	@echo "  sample-macro     - Build MacroSampleApp"
	@echo "  run-sample-macro - Run MacroSampleApp"
	@echo "  lint             - Lint code with SwiftLint"
	@echo "  format           - Format code with swift-format"
	@echo "  xcode            - Generate Xcode project"
	@echo "  update           - Update dependencies"
	@echo "  help             - Show this help"
