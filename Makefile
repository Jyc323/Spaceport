.PHONY: build universal install uninstall run logs clean

build:
	./scripts/build.sh

universal:
	./scripts/build.sh --universal

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

run: build
	./build/Spaceport.app/Contents/MacOS/Spaceport

logs:
	tail -f ~/Library/Logs/Spaceport.log

clean:
	rm -rf build .build
