PREFIX ?= /usr/local
SOURCES := $(wildcard Sources/*.swift)

screendim: $(SOURCES)
	swiftc -O $(SOURCES) -o $@

install: screendim
	install -d $(PREFIX)/bin
	install -m 755 screendim $(PREFIX)/bin/screendim

clean:
	rm -f screendim

.PHONY: install clean
