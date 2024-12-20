build:
	@ echo "-> Building binary..."
	@ zig build
.PHONY: build

test:
	@ echo "-> Starting tests..."
	@ zig test ./...
.PHONY: test
