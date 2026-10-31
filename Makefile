.PHONY: all build test verify package app run clean

all: app

build:
	swift build

test:
	swift test

verify:
	./scripts/verify_app_bundle.sh

package:
	./scripts/package_release.sh

app:
	./scripts/build_app.sh

run: app
	open PsrShot.app

clean:
	rm -rf .build PsrShot.app PsrShot.dmg PsrShot-macOS.zip
