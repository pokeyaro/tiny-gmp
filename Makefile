.PHONY: run build clean test

run:
	zig build run

build:
	zig build

clean:
	zig build --summary all clean
	rm -rf zig-out zig-cache

test:
	zig build test

help:
	@echo "Available targets:"
	@echo "  run   - Build and run the project"
	@echo "  build - Build the project"
	@echo "  clean - Clean build artifacts"
	@echo "  test  - Run tests"
