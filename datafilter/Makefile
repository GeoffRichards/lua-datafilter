PACKAGE=lua-datafilter
VERSION=$(shell head -1 Changes | sed 's/ .*//')
RELEASEDATE=$(shell head -1 Changes | sed 's/.* //')
PREFIX=/usr/local
DISTNAME=$(PACKAGE)-$(VERSION)

LIBDIR = $(PREFIX)/lib

# Uncomment this to run the regression tests with valgrind.
#VALGRIND = valgrind -q --leak-check=yes --show-reachable=yes --num-callers=10

OBJECTS = filter.lo
SOURCES := $(OBJECTS:.lo=.c)

LIBTOOL := libtool --quiet

CFLAGS := -ansi -pedantic -Wall -W -Wshadow -Wpointer-arith \
          -Wcast-align -Wwrite-strings -Wstrict-prototypes \
          -Wmissing-prototypes -Wnested-externs -Wno-long-long \
          $(shell pkg-config --cflags lua5.1) \
          -DVERSION=\"$(VERSION)\"
LDFLAGS := $(shell pkg-config --libs lua5.1)

# Uncomment this line to enable optimization.  Comment it out when running
# the test suite because it makes the assert() errors clearer and avoids
# warnings about ridiculously long string constants with some versions of gcc.
#CFLAGS := $(CFLAGS) -O3 -fomit-frame-pointer

# Uncomment this line to enable debugging.
DEBUG := -g

# Uncomment one of these lines to enable profiling and/or gcov coverage testing.
#DEBUG := $(DEBUG) -pg
#DEBUG := $(DEBUG) -fprofile-arcs -ftest-coverage

all: liblua-datafilter.la manpages

# This is for building the Windows DLL for the module.  You might have to
# tweak the location of the MingW32 compiler and the Lua library and include
# files to get it to work.  The defaults here are set up for the Lua libraries
# to be unpacked in the current directory, and to compile on Debian Linux
# with the Windows cross compiler from the 'mingw32' package.
WIN32CC = /usr/bin/i586-mingw32msvc-cc
WIN32CFLAGS := -O2 -I/usr/i586-mingw32msvc/include -Iinclude \
               -DVERSION=\"$(VERSION)\"
WIN32LDFLAGS := -L. -llua5.1 -L/usr/i586-mingw32msvc/lib \
                --no-undefined --enable-runtime-pseudo-reloc
win32bin: datafilter.dll
filter.win32.o: filter.c datafilter.h algo/*.c algorithms.c
	$(WIN32CC) $(DEBUG) $(WIN32CFLAGS) -c -o $@ $<
datafilter.dll: filter.win32.o
	$(WIN32CC) $(DEBUG) -O -Wl,-S -shared -o $@ $< $(WIN32LDFLAGS)

manpages: doc/lua-datafilter.3 doc/lua-datafilter-base64.3 doc/lua-datafilter-pctenc.3 doc/lua-datafilter-qp.3
doc/lua-datafilter.3: doc/lua-datafilter.pod
	sed 's/E<copy>/(c)/g' <$< | sed 's/E<ndash>/-/g' | \
	    pod2man --center="Lua module for munging data" \
	            --name="LUA-DATAFILTER" --section=3 \
	            --release="$(VERSION)" --date="$(RELEASEDATE)" >$@
doc/lua-datafilter-base64.3: doc/lua-datafilter-base64.pod
	sed 's/E<copy>/(c)/g' <$< | sed 's/E<ndash>/-/g' | \
	    pod2man --center="Base64 algorithms for Lua" \
	            --name="LUA-DATAFILTER-BASE64" --section=3 \
	            --release="$(VERSION)" --date="$(RELEASEDATE)" >$@
doc/lua-datafilter-pctenc.3: doc/lua-datafilter-pctenc.pod
	sed 's/E<copy>/(c)/g' <$< | sed 's/E<ndash>/-/g' | \
	    pod2man --center="Percent encoding algorithms for Lua" \
	            --name="LUA-DATAFILTER-PCTENC" --section=3 \
	            --release="$(VERSION)" --date="$(RELEASEDATE)" >$@
doc/lua-datafilter-qp.3: doc/lua-datafilter-qp.pod
	sed 's/E<copy>/(c)/g' <$< | sed 's/E<ndash>/-/g' | \
	    pod2man --center="Quoted-printable algorithms for Lua" \
	            --name="LUA-DATAFILTER-QP" --section=3 \
	            --release="$(VERSION)" --date="$(RELEASEDATE)" >$@

test: all
	for f in t/*.lua; do $(VALGRIND) lua $$f; done

install: all
	mkdir -p $(LUA_SPATH)
	install --mode=644 liblua-datafilter.so.0.0.0 $(LUA_SPATH)/datafilter.so
	mkdir -p $(PREFIX)/share/man/man3
	for manpage in datafilter datafilter-base64 datafilter-qp datafilter-pctenc; do \
	    gzip -c doc/lua-$$manpage.3 >$(PREFIX)/share/man/man3/lua-$$manpage.3.gz


checktmp:
	@if [ -e tmp ]; then \
	    echo "Can't proceed if file 'tmp' exists"; \
	    false; \
	fi
dist: all checktmp
	mkdir -p tmp/$(DISTNAME)
	tar cf - --files-from MANIFEST | (cd tmp/$(DISTNAME) && tar xf -)
	cd tmp && tar cf - $(DISTNAME) | gzip -9 >../$(DISTNAME).tar.gz
	cd tmp && tar cf - $(DISTNAME) | bzip2 -9 >../$(DISTNAME).tar.bz2
	rm -rf tmp
win32dist: win32bin checktmp
	mkdir -p tmp/$(DISTNAME).win32
	rm -f $(DISTNAME).win32.zip
	cp datafilter.dll tmp/$(DISTNAME).win32/
	cp README.win32bin tmp/$(DISTNAME).win32/README
	cd tmp && zip -q -r ../$(DISTNAME).win32.zip $(DISTNAME).win32
	rm -rf tmp


# Dependencies.
%.d: %.c
	@echo 'DEP>' $@
	@$(CC) -M $(CFLAGS) $< | \
	   sed -e 's,\($*\)\.o[ :]*,\1.lo $@ : ,g' > $@
-include $(SOURCES:.c=.d)

%.lo: %.c
	@echo 'CC>' $@
	@$(LIBTOOL) --mode=compile $(CC) $(CFLAGS) $(DEBUG) -c -o $@ $<
liblua-datafilter.la: filter.lo
	@echo 'LD>' $@
	@$(LIBTOOL) --mode=link $(CC) $(LDFLAGS) $(DEBUG) -o $@ $< -rpath $(LIBDIR)

filter.lo: algorithms.c
algorithms.c: algorithms.txt algorithms.pl
	./algorithms.pl $< $@

clean:
	rm -f *.o *.lo *.d core
	rm -f filter.win32.o datafilter.dll
	rm -rf liblua-datafilter.la .libs
	rm -f doc/lua-TODO.3
	rm -f gmon.out *.bb t/*.bb *.bbg t/*.bbg *.da t/*.da *.gcov t/*.gcov
realclean: clean
	rm -f algorithms.c

.PHONY: all win32bin test install checktmp dist win32dist clean realclean
