.PHONY: build test icon app dmg clean

build:
	swift build

test:
	swift test

icon:
	bash scripts/generate-icons.sh

app:
	bash scripts/build-app.sh

dmg:
	bash scripts/build-dmg.sh

clean:
	rm -rf .build dist
