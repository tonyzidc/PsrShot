.PHONY: all build test app run clean

all: app

build:
	swift build

test:
	swift test

app:
	./scripts/build_app.sh

run: app
	open PsrShot.app

clean:
	rm -rf .build PsrShot.app
